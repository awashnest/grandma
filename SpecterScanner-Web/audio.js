// ============================================================
// audio.js — Programmatic audio generation for Specter Scanner
// Uses Web Audio API exclusively (no external audio files)
// All volumes kept moderate and kid-friendly
// ============================================================

class AudioManager {
  constructor() {
    this.ctx = null;
    this.masterGain = null;
    this.droneOsc = null;
    this.droneLFO = null;
    this.droneGain = null;
    this.isInitialized = false;
  }

  // ----------------------------------------------------------
  // init() — Create AudioContext and master gain
  // ----------------------------------------------------------
  init() {
    if (this.isInitialized) return;

    const AudioCtx = window.AudioContext || window.webkitAudioContext;
    this.ctx = new AudioCtx();

    // Master gain — moderate volume, no jump scares
    this.masterGain = this.ctx.createGain();
    this.masterGain.gain.value = 0.35;
    this.masterGain.connect(this.ctx.destination);

    this.isInitialized = true;

    // If context is suspended (autoplay policy), it will be
    // resumed on the first user gesture via resume()
    return this;
  }

  // ----------------------------------------------------------
  // resume() — Resume AudioContext after user interaction
  // ----------------------------------------------------------
  resume() {
    if (this.ctx && this.ctx.state === "suspended") {
      return this.ctx.resume();
    }
    return Promise.resolve();
  }

  // ----------------------------------------------------------
  // _ensureRunning() — Helper to check context state
  // ----------------------------------------------------------
  _ensureRunning() {
    if (!this.isInitialized) this.init();
    if (this.ctx.state === "suspended") {
      this.ctx.resume();
    }
  }

  // ----------------------------------------------------------
  // startAmbientDrone() — Low sine oscillation with LFO
  // Quiet and atmospheric, continuous loop
  // ----------------------------------------------------------
  startAmbientDrone() {
    this._ensureRunning();

    // Don't double-start
    if (this.droneOsc) return;

    const now = this.ctx.currentTime;

    // Drone oscillator: low sine wave at ~95 Hz
    this.droneOsc = this.ctx.createOscillator();
    this.droneOsc.type = "sine";
    this.droneOsc.frequency.value = 95;

    // LFO to modulate the drone frequency between ~80-110 Hz
    this.droneLFO = this.ctx.createOscillator();
    this.droneLFO.type = "sine";
    this.droneLFO.frequency.value = 0.3; // slow modulation

    const lfoGain = this.ctx.createGain();
    lfoGain.gain.value = 15; // +/- 15 Hz modulation depth
    this.droneLFO.connect(lfoGain);
    lfoGain.connect(this.droneOsc.frequency);

    // Drone volume — quiet
    this.droneGain = this.ctx.createGain();
    this.droneGain.gain.setValueAtTime(0, now);
    this.droneGain.gain.linearRampToValueAtTime(0.25, now + 2);

    this.droneOsc.connect(this.droneGain);
    this.droneGain.connect(this.masterGain);

    this.droneLFO.start(now);
    this.droneOsc.start(now);

    // Store LFO gain for cleanup
    this._droneLFOGain = lfoGain;
  }

  // ----------------------------------------------------------
  // stopAmbientDrone() — Fade out and stop the drone
  // ----------------------------------------------------------
  stopAmbientDrone() {
    if (!this.droneOsc || !this.ctx) return;

    const now = this.ctx.currentTime;

    // Fade out over 2 seconds
    this.droneGain.gain.cancelScheduledValues(now);
    this.droneGain.gain.setValueAtTime(this.droneGain.gain.value, now);
    this.droneGain.gain.linearRampToValueAtTime(0, now + 2);

    // Stop and clean up after fade
    const osc = this.droneOsc;
    const lfo = this.droneLFO;
    const lfoGain = this._droneLFOGain;
    const droneGain = this.droneGain;

    setTimeout(() => {
      try {
        osc.stop();
        lfo.stop();
        osc.disconnect();
        lfo.disconnect();
        lfoGain.disconnect();
        droneGain.disconnect();
      } catch (e) {
        // Already stopped
      }
    }, 2100);

    this.droneOsc = null;
    this.droneLFO = null;
    this._droneLFOGain = null;
    this.droneGain = null;
  }

  // ----------------------------------------------------------
  // playDetectionSpike() — Quick frequency sweep 200Hz->2kHz
  // Duration: 0.3 seconds, moderate volume
  // ----------------------------------------------------------
  playDetectionSpike() {
    this._ensureRunning();

    const now = this.ctx.currentTime;
    const duration = 0.3;

    const osc = this.ctx.createOscillator();
    osc.type = "sine";
    osc.frequency.setValueAtTime(200, now);
    osc.frequency.exponentialRampToValueAtTime(2000, now + duration);

    const gain = this.ctx.createGain();
    gain.gain.setValueAtTime(0.3, now);
    gain.gain.setValueAtTime(0.3, now + duration * 0.7);
    gain.gain.linearRampToValueAtTime(0, now + duration);

    osc.connect(gain);
    gain.connect(this.masterGain);

    osc.start(now);
    osc.stop(now + duration);

    // Clean up after sound finishes
    osc.onended = () => {
      osc.disconnect();
      gain.disconnect();
    };
  }

  // ----------------------------------------------------------
  // _createWhiteNoiseBuffer() — Generate a buffer of white noise
  // ----------------------------------------------------------
  _createWhiteNoiseBuffer(durationSec) {
    const sampleRate = this.ctx.sampleRate;
    const length = Math.floor(sampleRate * durationSec);
    const buffer = this.ctx.createBuffer(1, length, sampleRate);
    const data = buffer.getChannelData(0);

    for (let i = 0; i < length; i++) {
      data[i] = Math.random() * 2 - 1;
    }
    return buffer;
  }

  // ----------------------------------------------------------
  // playStaticBurst() — White noise, 0.5s, quick attack/slow release
  // ----------------------------------------------------------
  playStaticBurst() {
    this._ensureRunning();

    const now = this.ctx.currentTime;
    const duration = 0.5;

    // White noise source
    const noiseBuffer = this._createWhiteNoiseBuffer(duration);
    const noiseSource = this.ctx.createBufferSource();
    noiseSource.buffer = noiseBuffer;

    // Bandpass filter to shape the static
    const filter = this.ctx.createBiquadFilter();
    filter.type = "bandpass";
    filter.frequency.value = 3000;
    filter.Q.value = 0.7;

    // Envelope: quick attack, slow release
    const gain = this.ctx.createGain();
    gain.gain.setValueAtTime(0, now);
    gain.gain.linearRampToValueAtTime(0.25, now + 0.02);  // 20ms attack
    gain.gain.setValueAtTime(0.25, now + 0.15);
    gain.gain.exponentialRampToValueAtTime(0.001, now + duration);

    noiseSource.connect(filter);
    filter.connect(gain);
    gain.connect(this.masterGain);

    noiseSource.start(now);
    noiseSource.stop(now + duration);

    // Clean up
    noiseSource.onended = () => {
      noiseSource.disconnect();
      filter.disconnect();
      gain.disconnect();
    };
  }

  // ----------------------------------------------------------
  // _createDelayReverb() — Simple delay-based reverb
  // Feedback delay network (no impulse response files needed)
  // ----------------------------------------------------------
  _createDelayReverb() {
    const ctx = this.ctx;

    // Input and output gain nodes
    const input = ctx.createGain();
    const output = ctx.createGain();
    output.gain.value = 1.0;

    // Dry signal path
    const dry = ctx.createGain();
    dry.gain.value = 0.4;
    input.connect(dry);
    dry.connect(output);

    // Wet signal: two parallel delay lines with feedback
    const delays = [0.11, 0.17]; // prime-ish ratios to avoid flutter
    const feedbacks = [0.6, 0.55];

    delays.forEach((delayTime, i) => {
      const delay = ctx.createDelay(1.0);
      delay.delayTime.value = delayTime;

      const feedback = ctx.createGain();
      feedback.gain.value = feedbacks[i];

      // Lowpass in feedback loop for natural decay
      const lpf = ctx.createBiquadFilter();
      lpf.type = "lowpass";
      lpf.frequency.value = 2500;

      const wet = ctx.createGain();
      wet.gain.value = 0.5;

      input.connect(delay);
      delay.connect(lpf);
      lpf.connect(feedback);
      feedback.connect(delay); // feedback loop
      lpf.connect(wet);
      wet.connect(output);
    });

    return { input, output };
  }

  // ----------------------------------------------------------
  // playEVPWhisper() — Sparse sine blips, random pitches, heavy reverb
  // Eerie but not real words. 1.5 second duration.
  // ----------------------------------------------------------
  playEVPWhisper() {
    this._ensureRunning();

    const now = this.ctx.currentTime;
    const totalDuration = 1.5;

    // Create reverb for this sound
    const reverb = this._createDelayReverb();
    reverb.output.connect(this.masterGain);

    // Overall envelope for the EVP effect
    const evpGain = this.ctx.createGain();
    evpGain.gain.setValueAtTime(0.2, now);
    evpGain.gain.linearRampToValueAtTime(0, now + totalDuration);
    evpGain.connect(reverb.input);

    // Schedule 5-8 sparse, short sine blips at random times
    const blipCount = 5 + Math.floor(Math.random() * 4);
    const scheduledNodes = [];

    for (let i = 0; i < blipCount; i++) {
      const startTime = now + Math.random() * (totalDuration * 0.8);
      const blipDuration = 0.03 + Math.random() * 0.07; // 30-100ms

      // Random pitch — eerie mid-high frequencies
      const freq = 400 + Math.random() * 2600; // 400-3000 Hz

      const osc = this.ctx.createOscillator();
      osc.type = "sine";
      osc.frequency.value = freq;

      // Slight pitch drift for eeriness
      osc.frequency.linearRampToValueAtTime(
        freq + (Math.random() - 0.5) * 200,
        startTime + blipDuration
      );

      const blipGain = this.ctx.createGain();
      blipGain.gain.setValueAtTime(0, startTime);
      blipGain.gain.linearRampToValueAtTime(
        0.1 + Math.random() * 0.12,
        startTime + 0.01
      );
      blipGain.gain.linearRampToValueAtTime(0, startTime + blipDuration);

      osc.connect(blipGain);
      blipGain.connect(evpGain);

      osc.start(startTime);
      osc.stop(startTime + blipDuration + 0.01);

      scheduledNodes.push({ osc, blipGain });
    }

    // Clean up after reverb tail dies out
    setTimeout(() => {
      scheduledNodes.forEach(({ osc, blipGain }) => {
        try {
          osc.disconnect();
          blipGain.disconnect();
        } catch (e) {
          // Already cleaned up
        }
      });
      try {
        evpGain.disconnect();
        reverb.input.disconnect();
        reverb.output.disconnect();
      } catch (e) {
        // Already cleaned up
      }
    }, (totalDuration + 1.5) * 1000); // extra time for reverb tail
  }

  // ----------------------------------------------------------
  // playAmbientPulse() — Very brief, quiet click/tap
  // For micro-glitch moments
  // ----------------------------------------------------------
  playAmbientPulse() {
    this._ensureRunning();

    const now = this.ctx.currentTime;

    // Extremely short noise burst — a click/tap
    const duration = 0.015; // 15ms

    const noiseBuffer = this._createWhiteNoiseBuffer(duration);
    const noiseSource = this.ctx.createBufferSource();
    noiseSource.buffer = noiseBuffer;

    // Highpass to make it a sharp click
    const hpf = this.ctx.createBiquadFilter();
    hpf.type = "highpass";
    hpf.frequency.value = 1500;

    // Very quiet
    const gain = this.ctx.createGain();
    gain.gain.setValueAtTime(0.12, now);
    gain.gain.linearRampToValueAtTime(0, now + duration);

    noiseSource.connect(hpf);
    hpf.connect(gain);
    gain.connect(this.masterGain);

    noiseSource.start(now);
    noiseSource.stop(now + duration);

    // Clean up
    noiseSource.onended = () => {
      noiseSource.disconnect();
      hpf.disconnect();
      gain.disconnect();
    };
  }
}

// Create and expose the global audio manager instance
window.audioManager = new AudioManager();
