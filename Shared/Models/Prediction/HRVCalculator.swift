//
//  HRVCalculator.swift
//  Headache Tracker
//
//  Created by Colin Campbell on 7/17/26.
//

import Foundation

/// Time- and frequency-domain heart-rate-variability measures derived from
/// beat-to-beat inter-beat intervals (IBIs), the data Apple exposes via
/// `HKHeartbeatSeriesSample`.
///
/// A single all-day SDNN value throws away the parasympathetic-dominant,
/// short-term variability that shifts in the migraine prodrome. RMSSD and
/// pNN50 recover it in the time domain; LF/HF characterizes the
/// sympatho-vagal balance in the frequency domain.
///
/// Input is an array of *segments* — one per heartbeat series — because
/// series are recorded intermittently and are not contiguous in time.
/// Successive-difference measures pool differences taken only *within* a
/// segment; the spectral measure is computed per qualifying segment and
/// averaged.
enum HRVCalculator {

  /// The minimum IBIs a segment needs before it can yield a spectrum.
  static let minimumSpectralSamples = 30

  /// The minimum segment duration (seconds) for a meaningful LF estimate
  /// (LF starts at 0.04 Hz, a 25 s period).
  static let minimumSpectralDuration = 20.0

  /// The resampling rate (Hz) for the evenly-gridded tachogram.
  private static let resampleRate = 4.0

  /// The successive absolute differences pooled across all segments (ms).
  private static func successiveDifferences(_ segments: [[Double]]) -> [Double] {
    var differences = [Double]()
    for segment in segments where segment.count >= 2 {
      for index in 1 ..< segment.count {
        differences.append(segment[index] - segment[index - 1])
      }
    }
    return differences
  }

  /// The root mean square of successive differences (ms).
  ///
  /// - Parameter segments: Per-series IBI arrays, in milliseconds.
  /// - Returns: RMSSD, or nil when there are no successive pairs.
  static func rmssd(segments: [[Double]]) -> Double? {
    let differences = successiveDifferences(segments)
    guard !differences.isEmpty else {
      return nil
    }
    let meanSquare = differences.reduce(0.0, { $0 + $1 * $1 }) / Double(differences.count)
    return meanSquare.squareRoot()
  }

  /// The proportion of successive differences greater than 50 ms.
  ///
  /// - Parameter segments: Per-series IBI arrays, in milliseconds.
  /// - Returns: pNN50 in [0, 1], or nil when there are no successive pairs.
  static func pnn50(segments: [[Double]]) -> Double? {
    let differences = successiveDifferences(segments)
    guard !differences.isEmpty else {
      return nil
    }
    let over = differences.lazy.filter({ abs($0) > 50.0 }).count
    return Double(over) / Double(differences.count)
  }

  /// The ratio of low-frequency (0.04–0.15 Hz) to high-frequency
  /// (0.15–0.40 Hz) spectral power, averaged over qualifying segments.
  ///
  /// - Parameter segments: Per-series IBI arrays, in milliseconds.
  /// - Returns: The mean LF/HF, or nil when no segment is long enough.
  static func lfhf(segments: [[Double]]) -> Double? {
    let ratios = segments.compactMap(lfhf(segment:))
    guard !ratios.isEmpty else {
      return nil
    }
    return ratios.reduce(0.0, +) / Double(ratios.count)
  }

  /// LF/HF for a single contiguous segment.
  private static func lfhf(segment: [Double]) -> Double? {
    guard segment.count >= minimumSpectralSamples else {
      return nil
    }

    // Tachogram sampled at each beat's midpoint time (seconds).
    var times = [Double]()
    var cumulative = 0.0
    for ibi in segment {
      let seconds = ibi / 1000.0
      times.append(cumulative + seconds / 2.0)
      cumulative += seconds
    }

    let meanIBI = segment.reduce(0.0, +) / Double(segment.count)
    let values = segment.map({ $0 - meanIBI })

    guard let first = times.first, let last = times.last else {
      return nil
    }
    let duration = last - first
    guard duration >= minimumSpectralDuration else {
      return nil
    }

    // Resample to an even grid via linear interpolation.
    let count = Int(duration * resampleRate)
    guard count >= 16 else {
      return nil
    }

    var resampled = [Double](repeating: 0.0, count: count)
    var cursor = 0
    for index in 0 ..< count {
      let time = first + Double(index) / resampleRate
      while cursor < times.count - 2 && times[cursor + 1] < time {
        cursor += 1
      }
      let x0 = times[cursor]
      let x1 = times[cursor + 1]
      let y0 = values[cursor]
      let y1 = values[cursor + 1]
      resampled[index] = x1 > x0 ? y0 + (y1 - y0) * (time - x0) / (x1 - x0) : y0
    }

    // Remove the mean so the DC bin doesn't dominate.
    let mean = resampled.reduce(0.0, +) / Double(count)
    for index in 0 ..< count {
      resampled[index] -= mean
    }

    // Apply a Hann window to curb spectral leakage between the LF and HF
    // bands. The LF/HF ratio is unaffected by the window's overall scale
    // since both bands are attenuated identically.
    if count > 1 {
      for index in 0 ..< count {
        let hann = 0.5 * (1.0 - cos(2.0 * Double.pi * Double(index) / Double(count - 1)))
        resampled[index] *= hann
      }
    }

    let lf = bandPower(resampled, sampleRate: resampleRate, low: 0.04, high: 0.15)
    let hf = bandPower(resampled, sampleRate: resampleRate, low: 0.15, high: 0.40)
    guard hf > 0.0 else {
      return nil
    }
    return lf / hf
  }

  /// The summed periodogram power in a frequency band.
  private static func bandPower(_ signal: [Double], sampleRate: Double, low: Double, high: Double) -> Double {
    let count = signal.count
    guard count > 1 else {
      return 0.0
    }

    // Half-open band [low, high): the upper bin is the largest strictly below
    // `high`. Using an inclusive `floor(high)` bound made a frequency landing
    // exactly on a bin boundary (0.15 Hz, shared by the LF and HF bands
    // whenever `0.15 · count / sampleRate` is integral) count in *both* bands,
    // biasing the LF/HF ratio toward 1. `ceil(high) - 1` equals the old
    // `floor(high)` for every non-integral boundary, so only the double-counted
    // case changes.
    let lowBin = max(1, Int((low * Double(count) / sampleRate).rounded(.up)))
    let highBin = min(count / 2, Int((high * Double(count) / sampleRate).rounded(.up)) - 1)
    guard lowBin <= highBin else {
      return 0.0
    }

    var power = 0.0
    for bin in lowBin ... highBin {
      var real = 0.0
      var imaginary = 0.0
      let omega = 2.0 * Double.pi * Double(bin) / Double(count)
      for index in 0 ..< count {
        let angle = omega * Double(index)
        real += signal[index] * cos(angle)
        imaginary -= signal[index] * sin(angle)
      }
      power += (real * real + imaginary * imaginary) / Double(count)
    }
    return power
  }

}
