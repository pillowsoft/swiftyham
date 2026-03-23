/**
 * Simplified SGP4 satellite orbit propagator.
 * Port of HamStationKit/Sources/Satellite/SGP4.swift
 */

import type { TLE } from './tle-parser';

const DEG2RAD = Math.PI / 180;
const TWOPI = 2 * Math.PI;
const MINUTES_PER_DAY = 1440;
const EARTH_RADIUS_KM = 6378.137;
const MU = 398600.4418 * 3600; // km³/min²
const J2 = 1.08262998905e-3;

export interface SatellitePosition {
  latitude: number;   // degrees
  longitude: number;  // degrees
  altitude: number;   // km
  velocity: number;   // km/s
}

/**
 * Propagate a satellite to a given date/time.
 */
export function propagate(tle: TLE, date: Date): SatellitePosition | null {
  const tsince = (date.getTime() - tle.epoch.getTime()) / 60000; // minutes

  const incl = tle.inclination * DEG2RAD;
  const raan0 = tle.raan * DEG2RAD;
  const ecc0 = tle.eccentricity;
  const argp0 = tle.argOfPerigee * DEG2RAD;
  const ma0 = tle.meanAnomaly * DEG2RAD;
  const n0 = tle.meanMotion * TWOPI / MINUTES_PER_DAY;
  const bstar = tle.bstar;

  const a1 = Math.pow(MU / (n0 * n0), 1 / 3);
  const cosIncl = Math.cos(incl);
  const cosIncl2 = cosIncl * cosIncl;
  const k2 = 0.5 * J2 * EARTH_RADIUS_KM * EARTH_RADIUS_KM;

  const d1 = 1.5 * k2 * (3 * cosIncl2 - 1) / (a1 * a1 * Math.pow(1 - ecc0 * ecc0, 1.5));
  const a0 = a1 * (1 - d1 / 3 - d1 * d1 - 134 / 81 * d1 * d1 * d1);
  const d0 = 1.5 * k2 * (3 * cosIncl2 - 1) / (a0 * a0 * Math.pow(1 - ecc0 * ecc0, 1.5));
  const noPrime = n0 / (1 + d0);
  const aoPrime = a0 / (1 - d0);

  // Secular rates
  const beta0sq = 1 - ecc0 * ecc0;
  const sinIncl = Math.sin(incl);
  const raanDot = -noPrime * k2 * cosIncl / (aoPrime * aoPrime * beta0sq) * 2;
  const argpDot = noPrime * k2 * (2 - 2.5 * sinIncl * sinIncl) / (aoPrime * aoPrime * beta0sq);

  // Mean elements at time
  const e = ecc0;
  const a = aoPrime;
  const mp = ma0 + noPrime * tsince;
  const argp = argp0 + argpDot * tsince;
  const raan = raan0 + raanDot * tsince;

  if (e >= 1 || e < 0 || a <= 0) return null;

  // Solve Kepler's equation
  const E = solveKepler(mp % TWOPI, e);
  const sinE = Math.sin(E);
  const cosE = Math.cos(E);

  const trueAnomaly = Math.atan2(Math.sqrt(1 - e * e) * sinE / (1 - e * cosE), (cosE - e) / (1 - e * cosE));

  const r = a * (1 - e * cosE);
  const rdot = Math.sqrt(MU * a) * e * sinE / r;
  const rfdot = Math.sqrt(MU * a) * Math.sqrt(1 - e * e) / r;

  const argLat = trueAnomaly + argp;
  const sinU = Math.sin(argLat);
  const cosU = Math.cos(argLat);
  const sinRaan = Math.sin(raan);
  const cosRaan = Math.cos(raan);
  const sinIk = Math.sin(incl);
  const cosIk = Math.cos(incl);

  const mx = -sinRaan * cosIk;
  const my = cosRaan * cosIk;
  const ux = mx * sinU + cosRaan * cosU;
  const uy = my * sinU + sinRaan * cosU;
  const uz = sinIk * sinU;
  const vx = mx * cosU - cosRaan * sinU;
  const vy = my * cosU - sinRaan * sinU;
  const vz = sinIk * cosU;

  const x = r * ux;
  const y = r * uy;
  const z = r * uz;
  const xdot = rdot * ux + rfdot * vx;
  const ydot = rdot * uy + rfdot * vy;
  const zdot = rdot * uz + rfdot * vz;

  return eciToGeodetic({ x, y, z, vx: xdot, vy: ydot, vz: zdot }, date);
}

function solveKepler(M: number, e: number): number {
  let ma = M % TWOPI;
  if (ma < 0) ma += TWOPI;
  let E = ma + e * Math.sin(ma) * (1 + e * Math.cos(ma));

  for (let i = 0; i < 20; i++) {
    const dE = (E - e * Math.sin(E) - ma) / (1 - e * Math.cos(E));
    E -= dE;
    if (Math.abs(dE) < 1e-12) break;
  }
  return E;
}

function eciToGeodetic(eci: { x: number; y: number; z: number; vx: number; vy: number; vz: number }, date: Date): SatellitePosition {
  const gmst = greenwichMeanSiderealTime(date);
  const rxy = Math.sqrt(eci.x * eci.x + eci.y * eci.y);

  let longitude = Math.atan2(eci.y, eci.x) - gmst;
  while (longitude < -Math.PI) longitude += TWOPI;
  while (longitude > Math.PI) longitude -= TWOPI;

  const e2 = 0.00669437999014;
  let latitude = Math.atan2(eci.z, rxy);
  for (let i = 0; i < 10; i++) {
    const sinLat = Math.sin(latitude);
    const N = EARTH_RADIUS_KM / Math.sqrt(1 - e2 * sinLat * sinLat);
    latitude = Math.atan2(eci.z + e2 * N * sinLat, rxy);
  }

  const sinLat = Math.sin(latitude);
  const N = EARTH_RADIUS_KM / Math.sqrt(1 - e2 * sinLat * sinLat);
  const cosLat = Math.cos(latitude);
  const altitude = cosLat !== 0
    ? rxy / cosLat - N
    : Math.abs(eci.z) - N * (1 - e2);

  const velocity = Math.sqrt(eci.vx * eci.vx + eci.vy * eci.vy + eci.vz * eci.vz) / 60;

  return {
    latitude: latitude / DEG2RAD,
    longitude: longitude / DEG2RAD,
    altitude,
    velocity,
  };
}

function greenwichMeanSiderealTime(date: Date): number {
  const jd = date.getTime() / 86400000 + 2440587.5;
  const T = (jd - 2451545.0) / 36525.0;
  let gmst = 280.46061837 + 360.98564736629 * (jd - 2451545.0)
           + 0.000387933 * T * T - T * T * T / 38710000;
  return (gmst % 360) * DEG2RAD;
}
