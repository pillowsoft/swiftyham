#!/usr/bin/env python3
"""
train_audio_denoiser.py — Train a Core ML spectral mask denoiser for ham radio audio.

Generates synthetic noisy/clean audio pairs simulating HF SSB, weak CW, and FM
conditions. Trains a small U-Net that predicts a spectral denoising mask from
STFT magnitude input. Exports a .mlmodel for AudioEnhancer.

Usage:
    python3 train_audio_denoiser.py [--output audio_denoiser.mlmodel] [--samples 20000]

Requirements:
    pip install numpy coremltools torch
"""

import argparse
import numpy as np
import sys

FFT_SIZE = 512
HALF_FFT = FFT_SIZE // 2
SAMPLE_RATE = 48000


def generate_clean_signal(signal_type: str, duration_ms: float = 20.0) -> np.ndarray:
    """Generate a clean signal segment."""
    n_samples = int(SAMPLE_RATE * duration_ms / 1000.0)
    t = np.arange(n_samples) / SAMPLE_RATE

    if signal_type == "ssb_voice":
        # Simulate voice-like spectrum: sum of harmonics with formant-like envelope
        freqs = np.random.uniform(200, 3000, size=np.random.randint(5, 15))
        signal = sum(np.random.uniform(0.1, 1.0) * np.sin(2 * np.pi * f * t) for f in freqs)
    elif signal_type == "cw_tone":
        freq = np.random.uniform(400, 1000)
        signal = np.sin(2 * np.pi * freq * t)
    elif signal_type == "fm_audio":
        # FM is cleaner, wider bandwidth
        freqs = np.random.uniform(100, 5000, size=np.random.randint(10, 30))
        signal = sum(np.random.uniform(0.05, 0.5) * np.sin(2 * np.pi * f * t) for f in freqs)
    else:
        signal = np.zeros(n_samples)

    return signal.astype(np.float32)


def add_hf_noise(signal: np.ndarray, snr_db: float) -> np.ndarray:
    """Add realistic HF noise (white + atmospheric + QRM)."""
    n = len(signal)
    # White noise base
    noise = np.random.randn(n).astype(np.float32)

    # Add some low-frequency atmospheric rumble
    t = np.arange(n) / SAMPLE_RATE
    atmo = 0.3 * np.sin(2 * np.pi * np.random.uniform(20, 200) * t)
    noise = noise + atmo.astype(np.float32)

    # Occasional impulse noise (static crashes)
    n_impulses = np.random.randint(0, 5)
    for _ in range(n_impulses):
        pos = np.random.randint(0, max(1, n - 10))
        noise[pos:pos + 10] += np.random.uniform(2, 5)

    # Scale to target SNR
    signal_power = np.mean(signal ** 2) + 1e-10
    noise_power = signal_power / (10 ** (snr_db / 10))
    current_noise_power = np.mean(noise ** 2) + 1e-10
    noise = noise * np.sqrt(noise_power / current_noise_power)

    return signal + noise


def compute_magnitude(signal: np.ndarray) -> np.ndarray:
    """Compute magnitude spectrum via FFT."""
    # Pad to FFT_SIZE
    if len(signal) < FFT_SIZE:
        signal = np.pad(signal, (0, FFT_SIZE - len(signal)))
    # Hann window
    window = np.hanning(FFT_SIZE).astype(np.float32)
    windowed = signal[:FFT_SIZE] * window
    spectrum = np.fft.rfft(windowed)
    return np.abs(spectrum[:HALF_FFT]).astype(np.float32)


def generate_training_data(n_samples: int) -> tuple:
    """Generate (noisy_magnitude, ideal_mask) pairs."""
    X = np.zeros((n_samples, HALF_FFT), dtype=np.float32)
    Y = np.zeros((n_samples, HALF_FFT), dtype=np.float32)

    signal_types = ["ssb_voice", "cw_tone", "fm_audio"]

    for i in range(n_samples):
        sig_type = np.random.choice(signal_types)
        snr = np.random.uniform(-5, 20)

        clean = generate_clean_signal(sig_type)
        noisy = add_hf_noise(clean, snr)

        clean_mag = compute_magnitude(clean)
        noisy_mag = compute_magnitude(noisy)

        # Ideal ratio mask (IRM): clean / noisy, clipped to [0, 1]
        mask = np.clip(clean_mag / (noisy_mag + 1e-8), 0, 1)

        # Normalize magnitudes
        peak = np.max(noisy_mag) + 1e-8
        X[i] = noisy_mag / peak
        Y[i] = mask

    return X, Y


def train_model(X_train, Y_train, X_val, Y_val):
    """Train a small MLP denoiser (spectral mask predictor)."""
    import torch
    import torch.nn as nn

    class SpectralDenoiser(nn.Module):
        """Simple feed-forward spectral mask predictor.
        Input: HALF_FFT magnitude bins. Output: HALF_FFT mask values [0, 1]."""
        def __init__(self):
            super().__init__()
            self.net = nn.Sequential(
                nn.Linear(HALF_FFT, 256),
                nn.ReLU(),
                nn.Dropout(0.2),
                nn.Linear(256, 256),
                nn.ReLU(),
                nn.Dropout(0.2),
                nn.Linear(256, HALF_FFT),
                nn.Sigmoid(),  # Mask output [0, 1]
            )

        def forward(self, x):
            return self.net(x)

    device = torch.device("mps" if torch.backends.mps.is_available() else "cpu")
    model = SpectralDenoiser().to(device)
    optimizer = torch.optim.Adam(model.parameters(), lr=1e-3)
    criterion = nn.MSELoss()

    X_t = torch.from_numpy(X_train).to(device)
    Y_t = torch.from_numpy(Y_train).to(device)
    X_v = torch.from_numpy(X_val).to(device)
    Y_v = torch.from_numpy(Y_val).to(device)

    batch_size = 256
    best_val_loss = float("inf")

    for epoch in range(30):
        model.train()
        indices = torch.randperm(len(X_t))
        total_loss = 0
        n_batches = 0

        for start in range(0, len(X_t), batch_size):
            batch_idx = indices[start:start + batch_size]
            xb, yb = X_t[batch_idx], Y_t[batch_idx]

            optimizer.zero_grad()
            out = model(xb)
            loss = criterion(out, yb)
            loss.backward()
            optimizer.step()
            total_loss += loss.item()
            n_batches += 1

        model.eval()
        with torch.no_grad():
            val_out = model(X_v)
            val_loss = criterion(val_out, Y_v).item()

        if val_loss < best_val_loss:
            best_val_loss = val_loss
            best_state = {k: v.cpu() for k, v in model.state_dict().items()}

        if (epoch + 1) % 5 == 0:
            print(f"  Epoch {epoch+1:3d}: loss={total_loss/n_batches:.6f}  val_loss={val_loss:.6f}")

    model.load_state_dict(best_state)
    model.eval().cpu()
    print(f"  Best validation loss: {best_val_loss:.6f}")
    return model


def export_coreml(model, output_path: str):
    """Export PyTorch model to Core ML."""
    import torch
    import coremltools as ct

    model.eval()
    dummy = torch.randn(1, HALF_FFT)
    traced = torch.jit.trace(model, dummy)

    ml_model = ct.convert(
        traced,
        inputs=[ct.TensorType(name="magnitude_input", shape=(1, HALF_FFT))],
        outputs=[ct.TensorType(name="denoising_mask")],
        convert_to="mlprogram",
        minimum_deployment_target=ct.target.macOS14,
    )

    ml_model.author = "HamStation Pro"
    ml_model.short_description = "Spectral mask denoiser for HF SSB, CW, and FM audio"
    ml_model.version = "1.0"

    ml_model.save(output_path)
    print(f"  Saved Core ML model to {output_path}")


def main():
    parser = argparse.ArgumentParser(description="Train audio denoiser Core ML model")
    parser.add_argument("--output", default="audio_denoiser.mlpackage", help="Output model path")
    parser.add_argument("--samples", type=int, default=20000, help="Training samples")
    args = parser.parse_args()

    print("Generating training data...")
    n_train = args.samples
    n_val = args.samples // 5
    X_train, Y_train = generate_training_data(n_train)
    X_val, Y_val = generate_training_data(n_val)

    print(f"Training on {n_train} samples, validating on {n_val}...")
    model = train_model(X_train, Y_train, X_val, Y_val)

    print("Exporting to Core ML...")
    export_coreml(model, args.output)
    print("Done!")


if __name__ == "__main__":
    main()
