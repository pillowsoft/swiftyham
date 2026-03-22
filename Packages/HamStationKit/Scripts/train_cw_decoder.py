#!/usr/bin/env python3
"""
train_cw_decoder.py — Train a Core ML CW element classifier.

Generates synthetic CW audio training data at varying speeds (5-50 WPM),
noise levels (-10dB to +20dB SNR), and tone frequencies (400-1000 Hz).
Trains a 1D CNN classifier and exports a .mlmodel for CoreMLCWDecoder.

Output classes: dit, dah, elementSpace, characterSpace, wordSpace, noise

Usage:
    python3 train_cw_decoder.py [--output cw_decoder.mlmodel] [--samples 50000]

Requirements:
    pip install numpy coremltools torch
"""

import argparse
import numpy as np
import sys

SAMPLE_RATE = 48000
WINDOW_SIZE = 512  # 10.67ms at 48kHz — matches CoreMLCWDecoder window

CLASSES = ["dit", "dah", "elementSpace", "characterSpace", "wordSpace", "noise"]


def dit_duration_ms(wpm: float) -> float:
    """Standard PARIS dit duration in milliseconds."""
    return 1200.0 / wpm


def generate_tone(duration_ms: float, freq_hz: float, sample_rate: int = SAMPLE_RATE) -> np.ndarray:
    """Generate a pure tone."""
    n_samples = int(sample_rate * duration_ms / 1000.0)
    t = np.arange(n_samples) / sample_rate
    return np.sin(2 * np.pi * freq_hz * t).astype(np.float32)


def generate_silence(duration_ms: float, sample_rate: int = SAMPLE_RATE) -> np.ndarray:
    """Generate silence."""
    n_samples = int(sample_rate * duration_ms / 1000.0)
    return np.zeros(n_samples, dtype=np.float32)


def add_noise(signal: np.ndarray, snr_db: float) -> np.ndarray:
    """Add Gaussian white noise at specified SNR."""
    signal_power = np.mean(signal ** 2) + 1e-10
    noise_power = signal_power / (10 ** (snr_db / 10))
    noise = np.random.randn(len(signal)).astype(np.float32) * np.sqrt(noise_power)
    return signal + noise


def generate_training_data(n_samples: int) -> tuple:
    """Generate labeled training windows."""
    X = np.zeros((n_samples, WINDOW_SIZE), dtype=np.float32)
    y = np.zeros(n_samples, dtype=np.int64)

    for i in range(n_samples):
        wpm = np.random.uniform(5, 50)
        freq = np.random.uniform(400, 1000)
        snr = np.random.uniform(-10, 20)
        label = np.random.randint(0, len(CLASSES))

        dit_ms = dit_duration_ms(wpm)

        if CLASSES[label] == "dit":
            signal = generate_tone(dit_ms, freq)
        elif CLASSES[label] == "dah":
            signal = generate_tone(dit_ms * 3, freq)
        elif CLASSES[label] == "elementSpace":
            signal = generate_silence(dit_ms)
        elif CLASSES[label] == "characterSpace":
            signal = generate_silence(dit_ms * 3)
        elif CLASSES[label] == "wordSpace":
            signal = generate_silence(dit_ms * 7)
        else:  # noise
            signal = np.random.randn(WINDOW_SIZE).astype(np.float32) * 0.1

        # Add noise
        if CLASSES[label] != "noise":
            signal = add_noise(signal, snr)

        # Pad or trim to WINDOW_SIZE
        if len(signal) >= WINDOW_SIZE:
            # Random offset within the signal
            offset = np.random.randint(0, max(1, len(signal) - WINDOW_SIZE))
            window = signal[offset:offset + WINDOW_SIZE]
        else:
            window = np.zeros(WINDOW_SIZE, dtype=np.float32)
            offset = np.random.randint(0, WINDOW_SIZE - len(signal))
            window[offset:offset + len(signal)] = signal

        # Normalize
        peak = np.max(np.abs(window)) + 1e-10
        window = window / peak

        X[i] = window
        y[i] = label

    return X, y


def train_model(X_train, y_train, X_val, y_val):
    """Train a simple 1D CNN classifier using PyTorch."""
    import torch
    import torch.nn as nn

    class CWClassifier(nn.Module):
        def __init__(self):
            super().__init__()
            self.features = nn.Sequential(
                nn.Conv1d(1, 16, kernel_size=15, stride=4, padding=7),
                nn.ReLU(),
                nn.Conv1d(16, 32, kernel_size=7, stride=2, padding=3),
                nn.ReLU(),
                nn.AdaptiveAvgPool1d(8),
            )
            self.classifier = nn.Sequential(
                nn.Flatten(),
                nn.Linear(32 * 8, 64),
                nn.ReLU(),
                nn.Dropout(0.3),
                nn.Linear(64, len(CLASSES)),
            )

        def forward(self, x):
            x = self.features(x)
            return self.classifier(x)

    device = torch.device("mps" if torch.backends.mps.is_available() else "cpu")
    model = CWClassifier().to(device)
    optimizer = torch.optim.Adam(model.parameters(), lr=1e-3)
    criterion = nn.CrossEntropyLoss()

    # Convert to tensors
    X_t = torch.from_numpy(X_train).unsqueeze(1).to(device)
    y_t = torch.from_numpy(y_train).to(device)
    X_v = torch.from_numpy(X_val).unsqueeze(1).to(device)
    y_v = torch.from_numpy(y_val).to(device)

    batch_size = 256
    best_val_acc = 0

    for epoch in range(30):
        model.train()
        indices = torch.randperm(len(X_t))
        total_loss = 0
        n_batches = 0

        for start in range(0, len(X_t), batch_size):
            batch_idx = indices[start:start + batch_size]
            xb, yb = X_t[batch_idx], y_t[batch_idx]

            optimizer.zero_grad()
            out = model(xb)
            loss = criterion(out, yb)
            loss.backward()
            optimizer.step()
            total_loss += loss.item()
            n_batches += 1

        # Validation
        model.eval()
        with torch.no_grad():
            val_out = model(X_v)
            val_pred = val_out.argmax(dim=1)
            val_acc = (val_pred == y_v).float().mean().item()

        if val_acc > best_val_acc:
            best_val_acc = val_acc
            best_state = {k: v.cpu() for k, v in model.state_dict().items()}

        if (epoch + 1) % 5 == 0:
            print(f"  Epoch {epoch+1:3d}: loss={total_loss/n_batches:.4f}  val_acc={val_acc:.3f}")

    model.load_state_dict(best_state)
    model.eval().cpu()
    print(f"  Best validation accuracy: {best_val_acc:.3f}")
    return model


def export_coreml(model, output_path: str):
    """Export PyTorch model to Core ML."""
    import torch
    import coremltools as ct

    model.eval()
    dummy = torch.randn(1, 1, WINDOW_SIZE)
    traced = torch.jit.trace(model, dummy)

    ml_model = ct.convert(
        traced,
        inputs=[ct.TensorType(name="audio_input", shape=(1, 1, WINDOW_SIZE))],
        outputs=[ct.TensorType(name="probabilities")],
        convert_to="mlprogram",
        minimum_deployment_target=ct.target.macOS14,
    )

    ml_model.author = "HamStation Pro"
    ml_model.short_description = "CW element classifier (dit/dah/space/noise) from 512-sample audio windows"
    ml_model.version = "1.0"

    ml_model.save(output_path)
    print(f"  Saved Core ML model to {output_path}")


def main():
    parser = argparse.ArgumentParser(description="Train CW decoder Core ML model")
    parser.add_argument("--output", default="cw_decoder.mlpackage", help="Output model path")
    parser.add_argument("--samples", type=int, default=50000, help="Training samples")
    args = parser.parse_args()

    print("Generating training data...")
    n_train = args.samples
    n_val = args.samples // 5
    X_train, y_train = generate_training_data(n_train)
    X_val, y_val = generate_training_data(n_val)

    print(f"Training on {n_train} samples, validating on {n_val}...")
    model = train_model(X_train, y_train, X_val, y_val)

    print("Exporting to Core ML...")
    export_coreml(model, args.output)
    print("Done!")


if __name__ == "__main__":
    main()
