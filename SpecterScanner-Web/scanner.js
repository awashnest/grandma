/**
 * scanner.js
 * Camera management and ghost detection simulation for the Specter Scanner web app.
 *
 * This module handles camera access, frame analysis, and simulated paranormal
 * detections. The detection system runs in "simulation mode" — it generates
 * convincing ghost sightings at random intervals rather than relying on a
 * trained ML model. The architecture is designed so that a real TensorFlow.js
 * classifier can be dropped in later with minimal changes.
 */

// ---------------------------------------------------------------------------
// Future ML Integration
// ---------------------------------------------------------------------------
// To add real ML classification:
// 1. Train a model using Teachable Machine (https://teachablemachine.withgoogle.com/)
//    - Create classes for each doll (use classificationLabel from DOLL_PROFILES)
//    - Add a "none" / background class for when no doll is visible
// 2. Export as TensorFlow.js model
// 3. Load with:
//      const model = await tf.loadLayersModel('model/model.json');
// 4. Replace simulateDetection() with real classification:
//      const predictions = model.predict(tf.browser.fromPixels(videoElement).expandDims());
//      const classIndex  = predictions.argMax(-1).dataSync()[0];
//      const confidence   = predictions.max(-1).dataSync()[0];
//    Then map classIndex back to the matching DOLL_PROFILES entry.
// 5. Remove the random-interval loop and instead classify every analysis tick.
// ---------------------------------------------------------------------------

class ScannerEngine {
  constructor() {
    /** @type {MediaStream|null} */
    this.stream = null;

    /** @type {ImageData|null} Previous frame pixel data for differencing. */
    this.previousFrameData = null;

    /** @type {number|null} ID returned by setInterval for the analysis loop. */
    this.analysisIntervalId = null;

    /** @type {number|null} ID returned by setTimeout for the next detection window. */
    this.detectionTimeoutId = null;

    /** @type {boolean} Whether the detection loop is active. */
    this.detecting = false;

    /** @type {number} Timestamp (ms) of the last successful detection. */
    this.lastDetectionTime = 0;

    /** @type {number} Detection cooldown in milliseconds. */
    this.detectionCooldownMs = 15000;

    /** @type {number} Running frame-difference accumulator (smoothed). */
    this.smoothedDifference = 0;

    /** @type {Function|null} Callback provided by the consumer. */
    this.onDetectionCallback = null;

    /** @type {HTMLVideoElement|null} Cached reference to the video element. */
    this._video = null;

    /** @type {HTMLCanvasElement|null} Cached reference to the scratch canvas. */
    this._canvas = null;
  }

  // =========================================================================
  // Camera Management
  // =========================================================================

  /**
   * Request camera access, preferring the rear-facing camera, and attach the
   * stream to the provided <video> element.
   *
   * @param {HTMLVideoElement} videoElement
   * @returns {Promise<MediaStream>}
   */
  async startCamera(videoElement) {
    // Stop any existing stream first.
    this.stopCamera();

    const constraints = {
      video: {
        facingMode: { ideal: "environment" },
        width: { ideal: 1280 },
        height: { ideal: 720 },
      },
      audio: false,
    };

    try {
      this.stream = await navigator.mediaDevices.getUserMedia(constraints);
    } catch (firstError) {
      // Rear camera unavailable — try any camera.
      try {
        this.stream = await navigator.mediaDevices.getUserMedia({
          video: true,
          audio: false,
        });
      } catch (secondError) {
        throw new Error(
          this._cameraErrorMessage(secondError)
        );
      }
    }

    videoElement.srcObject = this.stream;
    await videoElement.play().catch(() => {
      // Autoplay may be blocked; the 'muted' attribute usually prevents this.
    });

    return this.stream;
  }

  /**
   * Stop all tracks on the active media stream and detach from the video.
   */
  stopCamera() {
    if (this.stream) {
      this.stream.getTracks().forEach((track) => track.stop());
      this.stream = null;
    }
  }

  /**
   * Draw the current video frame onto a hidden canvas, apply a subtle
   * sepia / vintage filter, and return the result as a data URL.
   *
   * @param {HTMLVideoElement} videoElement
   * @param {HTMLCanvasElement} canvas
   * @returns {string} Data URL of the snapshot (image/png).
   */
  captureSnapshot(videoElement, canvas) {
    const ctx = canvas.getContext("2d");
    canvas.width = videoElement.videoWidth || 640;
    canvas.height = videoElement.videoHeight || 480;

    // Draw the raw frame.
    ctx.drawImage(videoElement, 0, 0, canvas.width, canvas.height);

    // Apply a vintage sepia tint.
    const imageData = ctx.getImageData(0, 0, canvas.width, canvas.height);
    const data = imageData.data;

    for (let i = 0; i < data.length; i += 4) {
      const r = data[i];
      const g = data[i + 1];
      const b = data[i + 2];

      // Sepia tone matrix (slightly desaturated warm tint).
      data[i]     = Math.min(255, r * 0.393 + g * 0.769 + b * 0.189); // R
      data[i + 1] = Math.min(255, r * 0.349 + g * 0.686 + b * 0.168); // G
      data[i + 2] = Math.min(255, r * 0.272 + g * 0.534 + b * 0.131); // B
      // Alpha stays the same.
    }

    ctx.putImageData(imageData, 0, 0);

    // Slight vignette via a radial gradient overlay.
    const cx = canvas.width / 2;
    const cy = canvas.height / 2;
    const radius = Math.max(cx, cy);
    const gradient = ctx.createRadialGradient(cx, cy, radius * 0.4, cx, cy, radius);
    gradient.addColorStop(0, "rgba(0,0,0,0)");
    gradient.addColorStop(1, "rgba(0,0,0,0.45)");
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, canvas.width, canvas.height);

    return canvas.toDataURL("image/png");
  }

  // =========================================================================
  // Detection Simulation
  // =========================================================================

  /**
   * Start the detection loop. An analysis tick runs every 500 ms to gather
   * frame statistics. A separate random-interval timer controls when an
   * actual detection roll occurs (every 3-8 seconds).
   *
   * @param {HTMLVideoElement} videoElement
   * @param {Function}         onDetection  Called as onDetection(dollProfile, confidence).
   */
  startDetectionLoop(videoElement, onDetection) {
    if (this.detecting) return;

    this.detecting = true;
    this.onDetectionCallback = onDetection;
    this._video = videoElement;

    // Ensure we have a scratch canvas.
    if (!this._canvas) {
      this._canvas = document.createElement("canvas");
    }

    // --- Analysis tick (500 ms) ---
    this.analysisIntervalId = setInterval(() => {
      this._analysisTick();
    }, 500);

    // --- Detection scheduling ---
    this._scheduleNextDetection();
  }

  /**
   * Stop the detection loop and clear all timers.
   */
  stopDetectionLoop() {
    this.detecting = false;
    this.onDetectionCallback = null;

    if (this.analysisIntervalId !== null) {
      clearInterval(this.analysisIntervalId);
      this.analysisIntervalId = null;
    }
    if (this.detectionTimeoutId !== null) {
      clearTimeout(this.detectionTimeoutId);
      this.detectionTimeoutId = null;
    }

    this.previousFrameData = null;
    this.smoothedDifference = 0;
    this._video = null;
  }

  // =========================================================================
  // Frame Analysis Helpers
  // =========================================================================

  /**
   * Sample the centre region of the video feed and return the average
   * brightness as a value between 0 (black) and 1 (white).
   *
   * @param {HTMLVideoElement} videoElement
   * @param {HTMLCanvasElement} canvas
   * @returns {number} Brightness 0-1.
   */
  getFrameBrightness(videoElement, canvas) {
    const ctx = canvas.getContext("2d");
    const sampleSize = 64; // Small sample is enough.
    canvas.width = sampleSize;
    canvas.height = sampleSize;

    ctx.drawImage(videoElement, 0, 0, sampleSize, sampleSize);

    const imageData = ctx.getImageData(
      sampleSize / 4,
      sampleSize / 4,
      sampleSize / 2,
      sampleSize / 2
    );
    const data = imageData.data;

    let total = 0;
    const pixelCount = data.length / 4;
    for (let i = 0; i < data.length; i += 4) {
      // Perceived luminance.
      total += data[i] * 0.299 + data[i + 1] * 0.587 + data[i + 2] * 0.114;
    }

    return total / (pixelCount * 255);
  }

  /**
   * Compare the current video frame to the previously stored frame and
   * return a 0-1 value representing how much has changed. 0 means identical,
   * 1 means completely different.
   *
   * @param {HTMLVideoElement} videoElement
   * @param {HTMLCanvasElement} canvas
   * @returns {number} Frame difference 0-1.
   */
  getFrameDifference(videoElement, canvas) {
    const ctx = canvas.getContext("2d");
    const sampleSize = 64;
    canvas.width = sampleSize;
    canvas.height = sampleSize;

    ctx.drawImage(videoElement, 0, 0, sampleSize, sampleSize);

    const currentData = ctx.getImageData(0, 0, sampleSize, sampleSize);

    if (!this.previousFrameData) {
      this.previousFrameData = currentData;
      return 0;
    }

    const curr = currentData.data;
    const prev = this.previousFrameData.data;
    let diffSum = 0;
    const pixelCount = curr.length / 4;

    for (let i = 0; i < curr.length; i += 4) {
      const dr = Math.abs(curr[i] - prev[i]);
      const dg = Math.abs(curr[i + 1] - prev[i + 1]);
      const db = Math.abs(curr[i + 2] - prev[i + 2]);
      diffSum += (dr + dg + db) / 3;
    }

    this.previousFrameData = currentData;

    return Math.min(1, diffSum / (pixelCount * 255));
  }

  // =========================================================================
  // Internal Helpers
  // =========================================================================

  /**
   * Runs every 500 ms to update frame statistics (brightness, difference).
   * These values feed into the detection probability calculation.
   * @private
   */
  _analysisTick() {
    if (!this._video || !this._canvas) return;

    try {
      const diff = this.getFrameDifference(this._video, this._canvas);
      // Exponential moving average for smooth transitions.
      this.smoothedDifference = this.smoothedDifference * 0.6 + diff * 0.4;
    } catch (_) {
      // Video may not be ready yet — ignore.
    }
  }

  /**
   * Schedule the next detection attempt after a random 3-8 second delay.
   * @private
   */
  _scheduleNextDetection() {
    if (!this.detecting) return;

    const delayMs = 3000 + Math.random() * 5000; // 3-8 seconds.
    this.detectionTimeoutId = setTimeout(() => {
      this._attemptDetection();
      this._scheduleNextDetection();
    }, delayMs);
  }

  /**
   * Roll the dice for a detection. Factors in cooldown, brightness, and
   * frame difference.
   * @private
   */
  _attemptDetection() {
    if (!this.detecting || !this._video || !this._canvas) return;
    if (!this.onDetectionCallback) return;

    // Respect cooldown.
    const now = Date.now();
    if (now - this.lastDetectionTime < this.detectionCooldownMs) return;

    // Skip if the camera is covered / too dark.
    let brightness;
    try {
      brightness = this.getFrameBrightness(this._video, this._canvas);
    } catch (_) {
      return;
    }
    if (brightness < 0.05) return; // Almost black — camera is likely covered.

    // Base detection chance: 15-25%.
    const baseChance = 0.15 + Math.random() * 0.10;

    // Bonus from visual movement (up to +15%).
    const movementBonus = Math.min(0.15, this.smoothedDifference * 0.5);

    const detectionChance = baseChance + movementBonus;

    if (Math.random() > detectionChance) return; // No detection this cycle.

    // --- Detection triggered! ---
    this.lastDetectionTime = now;

    const { doll, confidence } = this._pickDetection();
    this.onDetectionCallback(doll, confidence);
  }

  /**
   * Select a doll to "detect". Prefers undiscovered dolls when possible.
   * Returns the doll profile and a random confidence score.
   * @private
   * @returns {{ doll: object, confidence: number }}
   */
  _pickDetection() {
    // Determine which dolls have been discovered (stored in localStorage by app.js).
    let discoveredIds = [];
    try {
      const raw = localStorage.getItem("discoveredDolls");
      if (raw) discoveredIds = JSON.parse(raw);
    } catch (_) {
      // Ignore parse errors.
    }

    const undiscovered = DOLL_PROFILES.filter(
      (d) => !discoveredIds.includes(d.id)
    );
    const pool = undiscovered.length > 0 ? undiscovered : DOLL_PROFILES;

    const doll = pool[Math.floor(Math.random() * pool.length)];
    const confidence = 0.75 + Math.random() * 0.23; // 0.75 – 0.98

    return { doll, confidence };
  }

  /**
   * Produce a themed, user-friendly error message for camera failures.
   * @private
   * @param {Error} error
   * @returns {string}
   */
  _cameraErrorMessage(error) {
    if (
      error.name === "NotAllowedError" ||
      error.name === "PermissionDeniedError"
    ) {
      return (
        "CAMERA ACCESS DENIED\n\n" +
        "The Specter Scanner requires camera access to detect paranormal entities.\n" +
        "Please allow camera permissions in your browser settings and reload."
      );
    }
    if (
      error.name === "NotFoundError" ||
      error.name === "DevicesNotFoundError"
    ) {
      return (
        "NO CAMERA DETECTED\n\n" +
        "The Specter Scanner could not locate a camera on this device.\n" +
        "Paranormal detection requires a functioning camera feed."
      );
    }
    if (error.name === "NotReadableError" || error.name === "TrackStartError") {
      return (
        "CAMERA UNAVAILABLE\n\n" +
        "Another application may be using your camera.\n" +
        "Close other apps and try again to resume spectral scanning."
      );
    }
    return (
      "SCANNER MALFUNCTION\n\n" +
      "An unexpected error occurred while initializing the camera.\n" +
      "Error: " + error.message
    );
  }
}

// ---------------------------------------------------------------------------
// Instantiate the global scanner engine.
// ---------------------------------------------------------------------------
window.scanner = new ScannerEngine();
