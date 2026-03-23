/**
 * Satellite pass prediction using SGP4 propagation.
 */

import type { TLE } from './tle-parser';
import { propagate, type SatellitePosition } from './sgp4';

export interface SatellitePass {
  satellite: string;
  aos: Date;          // Acquisition of Signal
  los: Date;          // Loss of Signal
  maxElTime: Date;    // Time of maximum elevation
  maxElevation: number; // degrees
  aosAzimuth: number;   // degrees
  losAzimuth: number;   // degrees
  duration: number;      // seconds
}

interface ObserverLocation {
  latitude: number;
  longitude: number;
  altitude: number; // km
}

/**
 * Predict visible passes of a satellite over an observer location.
 */
export function predictPasses(
  tle: TLE,
  observer: ObserverLocation,
  startDate: Date = new Date(),
  days: number = 3,
  minElevation: number = 5
): SatellitePass[] {
  const passes: SatellitePass[] = [];
  const endTime = startDate.getTime() + days * 86400000;
  const stepMs = 30000; // 30 second steps for scanning
  const fineStepMs = 5000; // 5 second steps for pass refinement

  let t = startDate.getTime();
  let wasAboveHorizon = false;
  let passStart = 0;
  let maxEl = 0;
  let maxElTime = 0;
  let aosAz = 0;

  while (t < endTime && passes.length < 20) {
    const pos = propagate(tle, new Date(t));
    if (!pos) { t += stepMs; continue; }

    const lookAngles = computeLookAngles(pos, observer);

    if (lookAngles.elevation > 0) {
      if (!wasAboveHorizon) {
        // AOS
        passStart = t;
        aosAz = lookAngles.azimuth;
        maxEl = lookAngles.elevation;
        maxElTime = t;
        wasAboveHorizon = true;
      }
      if (lookAngles.elevation > maxEl) {
        maxEl = lookAngles.elevation;
        maxElTime = t;
      }
      t += fineStepMs;
    } else {
      if (wasAboveHorizon && maxEl >= minElevation) {
        // LOS — record pass
        passes.push({
          satellite: tle.name,
          aos: new Date(passStart),
          los: new Date(t),
          maxElTime: new Date(maxElTime),
          maxElevation: Math.round(maxEl),
          aosAzimuth: Math.round(aosAz),
          losAzimuth: Math.round(lookAngles.azimuth),
          duration: Math.round((t - passStart) / 1000),
        });
      }
      wasAboveHorizon = false;
      maxEl = 0;
      t += stepMs;
    }
  }

  return passes;
}

function computeLookAngles(sat: SatellitePosition, obs: ObserverLocation): { elevation: number; azimuth: number } {
  const DEG2RAD = Math.PI / 180;
  const satR = 6378.137 + sat.altitude;
  const obsR = 6378.137 + obs.altitude;

  const satLat = sat.latitude * DEG2RAD;
  const satLon = sat.longitude * DEG2RAD;
  const obsLat = obs.latitude * DEG2RAD;
  const obsLon = obs.longitude * DEG2RAD;

  // Convert to ECEF
  const satX = satR * Math.cos(satLat) * Math.cos(satLon);
  const satY = satR * Math.cos(satLat) * Math.sin(satLon);
  const satZ = satR * Math.sin(satLat);
  const obsX = obsR * Math.cos(obsLat) * Math.cos(obsLon);
  const obsY = obsR * Math.cos(obsLat) * Math.sin(obsLon);
  const obsZ = obsR * Math.sin(obsLat);

  // Range vector
  const rx = satX - obsX;
  const ry = satY - obsY;
  const rz = satZ - obsZ;
  const range = Math.sqrt(rx * rx + ry * ry + rz * rz);

  // Topocentric (South, East, Up)
  const sinLat = Math.sin(obsLat);
  const cosLat = Math.cos(obsLat);
  const sinLon = Math.sin(obsLon);
  const cosLon = Math.cos(obsLon);

  const south = sinLat * cosLon * rx + sinLat * sinLon * ry - cosLat * rz;
  const east = -sinLon * rx + cosLon * ry;
  const up = cosLat * cosLon * rx + cosLat * sinLon * ry + sinLat * rz;

  const elevation = Math.asin(up / range) / DEG2RAD;
  let azimuth = Math.atan2(east, -south) / DEG2RAD;
  if (azimuth < 0) azimuth += 360;

  return { elevation, azimuth };
}
