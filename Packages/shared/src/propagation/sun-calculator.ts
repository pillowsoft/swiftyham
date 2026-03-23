/**
 * Sunrise/sunset and grey line calculation.
 * Port of HamStationKit/Sources/Propagation/SunCalculator.swift
 * Uses NOAA Solar Calculator algorithm.
 */

export interface SolarTimes {
  sunrise?: Date;
  sunset?: Date;
  civilDawn?: Date;
  civilDusk?: Date;
  isDaytime: boolean;
  isPolarDay: boolean;
  isPolarNight: boolean;
}

export function solarTimes(latitude: number, longitude: number, date: Date = new Date()): SolarTimes {
  const jd = julianDay(date);
  const jc = (jd - 2451545) / 36525;

  const solarNoon = solarNoonUTC(jc, longitude);
  const ha = sunriseHourAngle(latitude, jc, 90.833);
  const civilHA = sunriseHourAngle(latitude, jc, 96);

  const startOfDay = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));

  if (isNaN(ha)) {
    const decl = sunDeclination(jc);
    const isPolarDay = (latitude > 0 && decl > 0) || (latitude < 0 && decl < 0);
    return { isDaytime: isPolarDay, isPolarDay, isPolarNight: !isPolarDay };
  }

  const sunriseMin = solarNoon - ha * 4;
  const sunsetMin = solarNoon + ha * 4;
  const sunrise = new Date(startOfDay.getTime() + sunriseMin * 60000);
  const sunset = new Date(startOfDay.getTime() + sunsetMin * 60000);

  let civilDawn: Date | undefined;
  let civilDusk: Date | undefined;
  if (!isNaN(civilHA)) {
    civilDawn = new Date(startOfDay.getTime() + (solarNoon - civilHA * 4) * 60000);
    civilDusk = new Date(startOfDay.getTime() + (solarNoon + civilHA * 4) * 60000);
  }

  return {
    sunrise, sunset, civilDawn, civilDusk,
    isDaytime: date >= sunrise && date <= sunset,
    isPolarDay: false, isPolarNight: false,
  };
}

/** Grey line terminator path as [lat, lon] pairs. */
export function greyLinePath(date: Date = new Date()): Array<{ latitude: number; longitude: number }> {
  const jd = julianDay(date);
  const jc = (jd - 2451545) / 36525;
  const decl = sunDeclination(jc);
  const decRad = decl * Math.PI / 180;
  const eot = equationOfTime(jc);

  const h = date.getUTCHours();
  const m = date.getUTCMinutes();
  const s = date.getUTCSeconds();
  const minSinceMidnight = h * 60 + m + s / 60;
  const sunLon = -(minSinceMidnight + eot - 720) / 4;

  const points: Array<{ latitude: number; longitude: number }> = [];
  for (let lon = -180; lon <= 180; lon += 2) {
    const lonRad = (lon - sunLon) * Math.PI / 180;
    const latRad = Math.abs(decRad) < 0.001 ? 0 : Math.atan(-Math.cos(lonRad) / Math.tan(decRad));
    points.push({ latitude: latRad * 180 / Math.PI, longitude: lon });
  }
  return points;
}

// Internal helpers
function julianDay(date: Date): number {
  return date.getTime() / 86400000 + 2440587.5;
}

function sunGeomMeanLong(t: number): number {
  let l0 = 280.46646 + t * (36000.76983 + 0.0003032 * t);
  l0 = l0 % 360;
  if (l0 < 0) l0 += 360;
  return l0;
}

function sunGeomMeanAnomaly(t: number): number {
  return 357.52911 + t * (35999.05029 - 0.0001537 * t);
}

function earthOrbitEccentricity(t: number): number {
  return 0.016708634 - t * (0.000042037 + 0.0000001267 * t);
}

function sunEquationOfCenter(t: number): number {
  const m = sunGeomMeanAnomaly(t) * Math.PI / 180;
  return Math.sin(m) * (1.914602 - t * (0.004817 + 0.000014 * t))
       + Math.sin(2 * m) * (0.019993 - 0.000101 * t)
       + Math.sin(3 * m) * 0.000289;
}

function sunApparentLong(t: number): number {
  const omega = 125.04 - 1934.136 * t;
  return sunGeomMeanLong(t) + sunEquationOfCenter(t) - 0.00569 - 0.00478 * Math.sin(omega * Math.PI / 180);
}

function meanObliquity(t: number): number {
  return 23 + (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60;
}

function obliquityCorrection(t: number): number {
  const omega = 125.04 - 1934.136 * t;
  return meanObliquity(t) + 0.00256 * Math.cos(omega * Math.PI / 180);
}

function sunDeclination(t: number): number {
  const e = obliquityCorrection(t);
  const lambda = sunApparentLong(t);
  return Math.asin(Math.sin(e * Math.PI / 180) * Math.sin(lambda * Math.PI / 180)) * 180 / Math.PI;
}

function equationOfTime(t: number): number {
  const e = earthOrbitEccentricity(t);
  const l0 = sunGeomMeanLong(t) * Math.PI / 180;
  const m = sunGeomMeanAnomaly(t) * Math.PI / 180;
  const y = Math.tan(obliquityCorrection(t) * Math.PI / 360);
  const ySq = y * y;
  const eot = ySq * Math.sin(2 * l0) - 2 * e * Math.sin(m)
            + 4 * e * ySq * Math.sin(m) * Math.cos(2 * l0)
            - 0.5 * ySq * ySq * Math.sin(4 * l0)
            - 1.25 * e * e * Math.sin(2 * m);
  return eot * 180 / Math.PI * 4;
}

function sunriseHourAngle(latitude: number, t: number, zenith: number): number {
  const latRad = latitude * Math.PI / 180;
  const decl = sunDeclination(t) * Math.PI / 180;
  const cosHA = (Math.cos(zenith * Math.PI / 180) / (Math.cos(latRad) * Math.cos(decl))) - Math.tan(latRad) * Math.tan(decl);
  if (cosHA > 1 || cosHA < -1) return NaN;
  return Math.acos(cosHA) * 180 / Math.PI;
}

function solarNoonUTC(t: number, longitude: number): number {
  return 720 - 4 * longitude - equationOfTime(t);
}
