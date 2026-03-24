/**
 * app.js
 * Main application controller for the Specter Scanner web app.
 * Orchestrates screen transitions, UI updates, user interactions,
 * and state management. Connects scanner, audio, and profiles modules.
 */

class App {
  constructor() {
    // State
    this.discoveries = new Map();
    this.scareLevel = 'junior';
    this.isScanning = false;
    this.currentDoll = null;

    // HUD intervals/timers
    this._hudTimers = {
      timestamp: null,
      emf: null,
      waveform: null,
      glitch: null,
    };
    this._waveformRAF = null;
    this._waveformPhase = 0;

    // Proximity simulator state
    this.emfLevel = 0.15;
    this.waveformAmplitude = 0.15;
    this._emfTarget = 0.15;
    this._waveformTarget = 0.15;

    // Screen IDs recognized by the app
    this._screens = [
      'launch-ritual',
      'scanner-view',
      'detection-alert',
      'doll-dossier',
      'case-files',
      'settings-modal',
    ];

    // Track where we came from when viewing a dossier
    this._dossierSource = 'scanner'; // 'scanner' or 'casefile'

    // Audio context resume flag
    this._audioResumed = false;
  }

  // ------------------------------------------------------------------
  // Initialization
  // ------------------------------------------------------------------

  init() {
    this._loadState();
    this._bindEvents();
    this._applyScareLevelUI();
    this.runLaunchSequence();
  }

  // ------------------------------------------------------------------
  // State persistence
  // ------------------------------------------------------------------

  _loadState() {
    // Discoveries
    try {
      const raw = localStorage.getItem('specterscanner_discoveries');
      if (raw) {
        const parsed = JSON.parse(raw);
        for (const [key, val] of Object.entries(parsed)) {
          this.discoveries.set(key, val);
        }
      }
    } catch (_) {
      // ignore corrupt data
    }

    // Scare level
    const level = localStorage.getItem('specterscanner_scare_level');
    if (level === 'junior' || level === 'senior') {
      this.scareLevel = level;
    }
  }

  _saveDiscoveries() {
    const obj = {};
    for (const [key, val] of this.discoveries.entries()) {
      obj[key] = val;
    }
    localStorage.setItem('specterscanner_discoveries', JSON.stringify(obj));
  }

  _saveScareLevel() {
    localStorage.setItem('specterscanner_scare_level', this.scareLevel);
  }

  // ------------------------------------------------------------------
  // Screen Management
  // ------------------------------------------------------------------

  showScreen(screenId) {
    for (const id of this._screens) {
      const el = document.getElementById(id);
      if (!el) continue;
      if (id === screenId) {
        el.classList.add('active');
        el.classList.remove('overlay');
      } else {
        el.classList.remove('active', 'overlay');
      }
    }
  }

  showOverlay(screenId) {
    const el = document.getElementById(screenId);
    if (!el) return;
    el.classList.add('active', 'overlay');
  }

  hideOverlay() {
    // Remove overlay from any non-scanner screen
    for (const id of this._screens) {
      if (id === 'scanner-view') continue;
      const el = document.getElementById(id);
      if (el) el.classList.remove('active', 'overlay');
    }
    // Ensure scanner is visible
    const scanner = document.getElementById('scanner-view');
    if (scanner) scanner.classList.add('active');
  }

  // ------------------------------------------------------------------
  // Launch Ritual
  // ------------------------------------------------------------------

  runLaunchSequence() {
    this.showScreen('launch-ritual');

    const bootLog = document.getElementById('boot-log');
    if (!bootLog) return;
    bootLog.innerHTML = '';

    const lines = [
      '> Initializing EMF array...',
      '> Calibrating thermal sensors...',
      '> Scanning spectral frequencies...',
      '> Loading entity database...',
      '> Cross-referencing paranormal signatures...',
      '> Establishing containment protocols...',
      '> Paranormal Detection System ONLINE',
    ];

    let index = 0;

    const addLine = () => {
      if (index >= lines.length) {
        // All lines shown — wait 1s then transition to scanner
        setTimeout(() => {
          this._startApp();
        }, 1000);
        return;
      }

      const p = document.createElement('p');
      p.className = 'boot-line flicker';
      p.textContent = lines[index];
      bootLog.appendChild(p);
      bootLog.scrollTop = bootLog.scrollHeight;

      // Remove flicker from previous lines
      const allLines = bootLog.querySelectorAll('.boot-line.flicker');
      for (let i = 0; i < allLines.length - 1; i++) {
        allLines[i].classList.remove('flicker');
      }

      index++;
      setTimeout(addLine, 800);
    };

    // Start after a brief initial delay
    setTimeout(addLine, 500);
  }

  _startApp() {
    this.showScreen('scanner-view');
    this._startCamera();
    this.startHUD();
    this.isScanning = true;
  }

  // ------------------------------------------------------------------
  // Camera
  // ------------------------------------------------------------------

  _startCamera() {
    const video = document.getElementById('camera-feed');
    if (!video) return;

    if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
      navigator.mediaDevices
        .getUserMedia({
          video: { facingMode: 'environment', width: { ideal: 1280 }, height: { ideal: 720 } },
          audio: false,
        })
        .then((stream) => {
          video.srcObject = stream;
          video.play().catch(() => {});

          // Start scanner module if available
          if (typeof Scanner !== 'undefined') {
            this._initScanner(video);
          }
        })
        .catch((err) => {
          console.warn('Camera not available:', err.message);
        });
    }
  }

  _initScanner(video) {
    if (typeof Scanner === 'undefined') return;
    try {
      this.scanner = new Scanner(video, {
        onDetection: (doll, confidence) => this._onDetection(doll, confidence),
      });
      this.scanner.start();
    } catch (_) {
      // Scanner module may have different API
    }
  }

  _captureSnapshot() {
    const video = document.getElementById('camera-feed');
    const canvas = document.getElementById('snapshot-canvas');
    if (!video || !canvas) return null;

    canvas.width = video.videoWidth || 640;
    canvas.height = video.videoHeight || 480;
    const ctx = canvas.getContext('2d');
    ctx.drawImage(video, 0, 0, canvas.width, canvas.height);

    try {
      return canvas.toDataURL('image/jpeg', 0.7);
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------------
  // HUD Management
  // ------------------------------------------------------------------

  startHUD() {
    this.stopHUD();

    // Timestamp — update every second
    this._hudTimers.timestamp = setInterval(() => {
      this._updateTimestamp();
    }, 1000);
    this._updateTimestamp();

    // EMF bars — fluctuate every 150ms
    this._hudTimers.emf = setInterval(() => {
      this._tickProximity();
      this.updateEMFBars(this.emfLevel);
    }, 150);

    // Waveform — draw every 50ms via rAF loop
    this._startWaveformLoop();

    // Random micro-glitches every 15-45s
    this._scheduleGlitch();
  }

  stopHUD() {
    if (this._hudTimers.timestamp) clearInterval(this._hudTimers.timestamp);
    if (this._hudTimers.emf) clearInterval(this._hudTimers.emf);
    if (this._hudTimers.glitch) clearTimeout(this._hudTimers.glitch);
    if (this._waveformRAF) cancelAnimationFrame(this._waveformRAF);
    this._hudTimers = { timestamp: null, emf: null, waveform: null, glitch: null };
    this._waveformRAF = null;
  }

  _updateTimestamp() {
    const el = document.getElementById('hud-timestamp');
    if (!el) return;
    const now = new Date();
    const pad = (n) => String(n).padStart(2, '0');
    el.textContent =
      now.getFullYear() +
      '-' +
      pad(now.getMonth() + 1) +
      '-' +
      pad(now.getDate()) +
      ' ' +
      pad(now.getHours()) +
      ':' +
      pad(now.getMinutes()) +
      ':' +
      pad(now.getSeconds());
  }

  // ------------------------------------------------------------------
  // EMF Bars
  // ------------------------------------------------------------------

  updateEMFBars(level) {
    const bars = document.querySelectorAll('#emf-meter .emf-bar');
    if (!bars.length) return;

    const count = bars.length; // 8

    for (let i = 0; i < count; i++) {
      const bar = bars[i];
      // Each bar has a threshold — lower-index bars fill first
      const threshold = (i + 1) / count;
      let height;

      if (level >= threshold) {
        height = 80 + Math.random() * 20; // 80-100%
      } else if (level >= threshold - 0.15) {
        height = 30 + Math.random() * 40; // partial fill
      } else {
        height = 5 + Math.random() * 10; // minimal
      }

      bar.style.height = height + '%';

      // Color based on level
      if (level > 0.75) {
        bar.style.backgroundColor = '#ff2222';
      } else if (level > 0.5) {
        bar.style.backgroundColor = '#ff8800';
      } else {
        bar.style.backgroundColor = '#00ff41';
      }
    }
  }

  // ------------------------------------------------------------------
  // Waveform Drawing
  // ------------------------------------------------------------------

  _startWaveformLoop() {
    const canvas = document.getElementById('waveform-canvas');
    if (!canvas) return;

    let lastDraw = 0;
    const drawInterval = 50; // ms between redraws

    const loop = (timestamp) => {
      this._waveformRAF = requestAnimationFrame(loop);
      if (timestamp - lastDraw < drawInterval) return;
      lastDraw = timestamp;

      this._tickProximity();
      this.drawWaveform(canvas, this.waveformAmplitude);
    };

    this._waveformRAF = requestAnimationFrame(loop);
  }

  drawWaveform(canvas, amplitude) {
    const ctx = canvas.getContext('2d');
    const w = canvas.width;
    const h = canvas.height;

    ctx.clearRect(0, 0, w, h);

    // Draw oscillating sine wave
    ctx.beginPath();
    ctx.strokeStyle = '#00ff41';
    ctx.lineWidth = 1.5;
    ctx.shadowColor = '#00ff41';
    ctx.shadowBlur = 4;

    const midY = h / 2;
    const amp = amplitude * midY * 0.9;
    const frequency = 3 + amplitude * 4; // more waves when amplitude higher

    this._waveformPhase += 0.12;

    for (let x = 0; x < w; x++) {
      const t = (x / w) * Math.PI * 2 * frequency + this._waveformPhase;
      const noise = (Math.random() - 0.5) * amplitude * 6;
      const y = midY + Math.sin(t) * amp + noise;

      if (x === 0) {
        ctx.moveTo(x, y);
      } else {
        ctx.lineTo(x, y);
      }
    }

    ctx.stroke();
    ctx.shadowBlur = 0;

    // Secondary wave (dimmer)
    ctx.beginPath();
    ctx.strokeStyle = 'rgba(0, 255, 65, 0.3)';
    ctx.lineWidth = 1;

    for (let x = 0; x < w; x++) {
      const t = (x / w) * Math.PI * 2 * (frequency * 0.7) + this._waveformPhase * 1.3;
      const y = midY + Math.sin(t) * amp * 0.5;

      if (x === 0) {
        ctx.moveTo(x, y);
      } else {
        ctx.lineTo(x, y);
      }
    }

    ctx.stroke();
  }

  // ------------------------------------------------------------------
  // Proximity Simulator (lerp-based EMF / waveform)
  // ------------------------------------------------------------------

  _tickProximity() {
    // Smooth interpolation toward targets
    const lerpRate = 0.08;
    this.emfLevel += (this._emfTarget - this.emfLevel) * lerpRate;
    this.waveformAmplitude += (this._waveformTarget - this.waveformAmplitude) * lerpRate;

    // Ambient fluctuation on targets
    if (!this._detectionActive) {
      this._emfTarget = 0.1 + Math.random() * 0.2; // 0.1 - 0.3
      this._waveformTarget = 0.1 + Math.random() * 0.2;
    }
  }

  _spikeProximity() {
    this._detectionActive = true;
    this._emfTarget = 0.8 + Math.random() * 0.2; // 0.8 - 1.0
    this._waveformTarget = 0.8 + Math.random() * 0.2;
  }

  _resetProximity() {
    this._detectionActive = false;
    this._emfTarget = 0.1 + Math.random() * 0.2;
    this._waveformTarget = 0.1 + Math.random() * 0.2;
  }

  // ------------------------------------------------------------------
  // Micro-Glitch Scheduler
  // ------------------------------------------------------------------

  _scheduleGlitch() {
    const delay = (15 + Math.random() * 30) * 1000; // 15-45 seconds
    this._hudTimers.glitch = setTimeout(() => {
      this._triggerGlitch();
      this._scheduleGlitch();
    }, delay);
  }

  _triggerGlitch() {
    const overlay = document.getElementById('glitch-overlay');
    if (!overlay) return;
    overlay.classList.add('glitch-active');
    setTimeout(() => {
      overlay.classList.remove('glitch-active');
    }, 150 + Math.random() * 200);
  }

  // ------------------------------------------------------------------
  // Detection Flow
  // ------------------------------------------------------------------

  _onDetection(doll, confidence) {
    if (!doll) return;
    this.currentDoll = doll;

    // 1. Spike EMF / waveform
    this._spikeProximity();
    this.updateEMFBars(0.9);

    // 2. Play detection spike audio + haptic
    if (typeof AudioManager !== 'undefined' && this.audio) {
      try {
        this.audio.playDetectionSpike();
      } catch (_) {}
    }
    if (navigator.vibrate) {
      navigator.vibrate([100, 50, 100, 50, 200]);
    }

    // 3. Capture camera snapshot
    const snapshot = this._captureSnapshot();

    // 4. After 1.5s buildup, show detection alert
    setTimeout(() => {
      this._showDetectionAlert(doll, confidence, snapshot);
    }, 1500);
  }

  _showDetectionAlert(doll, confidence, snapshot) {
    // Populate detection screen
    const nameEl = document.getElementById('detection-name');
    const classEl = document.getElementById('detection-class');
    const threatFill = document.getElementById('threat-bar-fill');
    const threatVal = document.getElementById('threat-value');
    const docEl = document.getElementById('detection-documented');

    if (nameEl) nameEl.textContent = doll.name.toUpperCase();

    const hauntingInfo = HAUNTING_TYPES[doll.hauntingType];
    if (classEl) {
      classEl.textContent =
        'Class: ' + (hauntingInfo ? hauntingInfo.displayName + ' Haunting' : 'Unknown');
    }

    if (threatFill) {
      threatFill.style.width = (doll.threatLevel / 5) * 100 + '%';
    }
    if (threatVal) {
      threatVal.textContent = doll.threatLevel + '/5';
    }

    // Show previously documented badge if already discovered
    const wasDiscovered = this.discoveries.has(doll.id);
    if (docEl) {
      docEl.classList.toggle('hidden', !wasDiscovered);
    }

    // Save discovery
    if (!wasDiscovered) {
      this.discoveries.set(doll.id, {
        discoveredAt: new Date().toISOString(),
        imageDataUrl: snapshot,
      });
      this._saveDiscoveries();
    }

    // Play EVP whisper
    if (typeof AudioManager !== 'undefined' && this.audio) {
      try {
        this.audio.playEVPWhisper();
      } catch (_) {}
    }

    // Show detection overlay
    this.showOverlay('detection-alert');
  }

  // ------------------------------------------------------------------
  // Dossier Rendering
  // ------------------------------------------------------------------

  renderDossier(doll) {
    if (!doll) return;
    this.currentDoll = doll;

    const fileNum = document.getElementById('dossier-file-number');
    const photo = document.getElementById('dossier-photo');
    const name = document.getElementById('dossier-name');
    const hauntIcon = document.getElementById('dossier-haunting-icon');
    const hauntText = document.getElementById('dossier-haunting-text');
    const threatDots = document.getElementById('dossier-threat-dots');
    const origin = document.getElementById('dossier-origin');
    const activityList = document.getElementById('dossier-activity');
    const firstDetected = document.getElementById('dossier-first-detected');
    const status = document.getElementById('dossier-status');

    // File number from ID
    const idNum = doll.id.replace('doll_', '');
    if (fileNum) fileNum.textContent = '#00-' + idNum.padStart(3, '0');

    // Photo — use discovered snapshot or placeholder
    if (photo) {
      const disc = this.discoveries.get(doll.id);
      if (disc && disc.imageDataUrl) {
        photo.src = disc.imageDataUrl;
      } else {
        photo.src = '';
      }
      photo.alt = doll.name + ' photograph';
    }

    // Name
    if (name) name.textContent = doll.name;

    // Haunting type
    const hauntingInfo = HAUNTING_TYPES[doll.hauntingType];
    if (hauntIcon) hauntIcon.textContent = hauntingInfo ? hauntingInfo.icon : '';
    if (hauntText) hauntText.textContent = hauntingInfo ? hauntingInfo.displayName : 'Unknown';

    // Threat dots (1-5 scale)
    if (threatDots) {
      let dots = '';
      for (let i = 1; i <= 5; i++) {
        dots += i <= doll.threatLevel ? '\u25CF' : '\u25CB';
      }
      threatDots.textContent = dots;
    }

    // Origin story
    if (origin) origin.textContent = doll.originStory;

    // Activity list
    if (activityList) {
      activityList.innerHTML = '';
      if (doll.documentedActivity && doll.documentedActivity.length > 0) {
        for (const act of doll.documentedActivity) {
          const li = document.createElement('li');
          li.textContent = act;
          activityList.appendChild(li);
        }
      } else {
        const li = document.createElement('li');
        li.textContent = 'No documented activity.';
        activityList.appendChild(li);
      }
    }

    // First detected timestamp
    if (firstDetected) {
      const disc = this.discoveries.get(doll.id);
      if (disc && disc.discoveredAt) {
        const d = new Date(disc.discoveredAt);
        firstDetected.textContent =
          d.getFullYear() +
          '-' +
          String(d.getMonth() + 1).padStart(2, '0') +
          '-' +
          String(d.getDate()).padStart(2, '0') +
          ' ' +
          String(d.getHours()).padStart(2, '0') +
          ':' +
          String(d.getMinutes()).padStart(2, '0');
      } else {
        firstDetected.textContent = '--';
      }
    }

    // Status badge
    if (status) {
      const statusMap = {
        contained: 'CONTAINED',
        under_observation: 'UNDER OBSERVATION',
        active: 'ACTIVE',
      };
      status.textContent = statusMap[doll.status] || doll.status.toUpperCase();
      status.className = 'dossier-status-badge status-' + doll.status.replace('_', '-');
    }
  }

  // ------------------------------------------------------------------
  // Case Files Grid
  // ------------------------------------------------------------------

  renderCaseFiles() {
    const grid = document.getElementById('case-files-grid');
    const counter = document.getElementById('case-files-counter');
    if (!grid) return;

    grid.innerHTML = '';
    let discoveredCount = 0;

    for (const doll of DOLL_PROFILES) {
      const discovered = this.discoveries.has(doll.id);
      if (discovered) discoveredCount++;

      const card = document.createElement('div');
      card.className = 'case-card ' + (discovered ? 'discovered' : 'undiscovered');
      card.setAttribute('data-id', doll.id);

      if (discovered) {
        const disc = this.discoveries.get(doll.id);
        const thumb = document.createElement('div');
        thumb.className = 'case-card-thumb';

        if (disc.imageDataUrl) {
          const img = document.createElement('img');
          img.src = disc.imageDataUrl;
          img.alt = doll.name;
          thumb.appendChild(img);
        }

        const nameP = document.createElement('p');
        nameP.className = 'case-card-name';
        nameP.textContent = doll.name;

        const threat = document.createElement('span');
        threat.className = 'case-card-threat';
        let dots = '';
        for (let i = 1; i <= 5; i++) {
          dots += i <= doll.threatLevel ? '\u25CF' : '\u25CB';
        }
        threat.textContent = dots;

        card.appendChild(thumb);
        card.appendChild(nameP);
        card.appendChild(threat);

        // Click handler to view dossier
        card.addEventListener('click', () => {
          this._dossierSource = 'casefile';
          this.renderDossier(doll);
          this.showOverlay('doll-dossier');
        });
      } else {
        const thumb = document.createElement('div');
        thumb.className = 'case-card-thumb silhouette';
        thumb.textContent = '???';

        const nameP = document.createElement('p');
        nameP.className = 'case-card-name';
        nameP.textContent = 'UNDETECTED';

        card.appendChild(thumb);
        card.appendChild(nameP);
      }

      grid.appendChild(card);
    }

    if (counter) {
      counter.textContent =
        discoveredCount + ' of ' + DOLL_PROFILES.length + ' Entities Documented';
    }
  }

  // ------------------------------------------------------------------
  // Settings
  // ------------------------------------------------------------------

  _applyScareLevelUI() {
    const toggle = document.getElementById('scare-toggle');
    if (!toggle) return;
    const options = toggle.querySelectorAll('.scare-option');
    options.forEach((opt) => {
      if (opt.getAttribute('data-level') === this.scareLevel) {
        opt.classList.add('active');
      } else {
        opt.classList.remove('active');
      }
    });
  }

  _handleScareToggle(level) {
    this.scareLevel = level;
    this._saveScareLevel();
    this._applyScareLevelUI();
  }

  _resetAllDiscoveries() {
    this.discoveries.clear();
    this._saveDiscoveries();
  }

  // ------------------------------------------------------------------
  // Audio Initialization (autoplay policy handling)
  // ------------------------------------------------------------------

  _initAudio() {
    if (typeof AudioManager !== 'undefined') {
      try {
        this.audio = new AudioManager();
      } catch (_) {
        this.audio = null;
      }
    }
  }

  _resumeAudioContext() {
    if (this._audioResumed) return;
    this._audioResumed = true;

    if (this.audio && typeof this.audio.resume === 'function') {
      try {
        this.audio.resume();
      } catch (_) {}
    }

    // Also try raw AudioContext resume
    if (this.audio && this.audio.ctx && this.audio.ctx.state === 'suspended') {
      this.audio.ctx.resume().catch(() => {});
    }
  }

  // ------------------------------------------------------------------
  // Event Binding
  // ------------------------------------------------------------------

  _bindEvents() {
    // First-tap audio resume handler
    const resumeHandler = () => {
      this._resumeAudioContext();
      document.removeEventListener('touchstart', resumeHandler);
      document.removeEventListener('click', resumeHandler);
    };
    document.addEventListener('touchstart', resumeHandler, { once: true });
    document.addEventListener('click', resumeHandler, { once: true });

    // Initialize audio manager
    this._initAudio();

    // Case Files button
    const btnCaseFiles = document.getElementById('btn-case-files');
    if (btnCaseFiles) {
      btnCaseFiles.addEventListener('click', () => {
        this.renderCaseFiles();
        this.showOverlay('case-files');
      });
    }

    // Settings button
    const btnSettings = document.getElementById('btn-settings');
    if (btnSettings) {
      btnSettings.addEventListener('click', () => {
        this._applyScareLevelUI();
        this.showOverlay('settings-modal');
      });
    }

    // Scan button (manual trigger for demo/testing)
    const btnScan = document.getElementById('btn-scan');
    if (btnScan) {
      btnScan.addEventListener('click', () => {
        this._resumeAudioContext();
        // Trigger a random detection for demonstration
        if (DOLL_PROFILES && DOLL_PROFILES.length > 0) {
          const randomDoll =
            DOLL_PROFILES[Math.floor(Math.random() * DOLL_PROFILES.length)];
          this._onDetection(randomDoll, 0.7 + Math.random() * 0.3);
        }
      });
    }

    // Detection alert — View Case File
    const btnViewDossier = document.getElementById('btn-view-dossier');
    if (btnViewDossier) {
      btnViewDossier.addEventListener('click', () => {
        if (this.currentDoll) {
          this._dossierSource = 'scanner';
          this.renderDossier(this.currentDoll);
          // Replace detection overlay with dossier overlay
          const detectionScreen = document.getElementById('detection-alert');
          if (detectionScreen) detectionScreen.classList.remove('active', 'overlay');
          this.showOverlay('doll-dossier');
        }
      });
    }

    // Detection alert — Dismiss / Return to scanner
    const btnDismiss = document.getElementById('btn-dismiss-alert');
    if (btnDismiss) {
      btnDismiss.addEventListener('click', () => {
        this.hideOverlay();
        this._resetProximity();
      });
    }

    // Dossier — Close
    const btnCloseDossier = document.getElementById('btn-close-dossier');
    if (btnCloseDossier) {
      btnCloseDossier.addEventListener('click', () => {
        const dossierScreen = document.getElementById('doll-dossier');
        if (dossierScreen) dossierScreen.classList.remove('active', 'overlay');

        if (this._dossierSource === 'casefile') {
          // Return to case files
          this.renderCaseFiles();
          this.showOverlay('case-files');
        } else {
          // Return to scanner
          this.hideOverlay();
          this._resetProximity();
        }
      });
    }

    // Case Files — Back button
    const btnCloseCases = document.getElementById('btn-close-cases');
    if (btnCloseCases) {
      btnCloseCases.addEventListener('click', () => {
        this.hideOverlay();
      });
    }

    // Settings — Close button
    const btnCloseSettings = document.getElementById('btn-close-settings');
    if (btnCloseSettings) {
      btnCloseSettings.addEventListener('click', () => {
        this.hideOverlay();
      });
    }

    // Settings — Backdrop click to close
    const settingsBackdrop = document.getElementById('settings-backdrop');
    if (settingsBackdrop) {
      settingsBackdrop.addEventListener('click', () => {
        this.hideOverlay();
      });
    }

    // Scare level toggle
    const scareToggle = document.getElementById('scare-toggle');
    if (scareToggle) {
      scareToggle.addEventListener('click', (e) => {
        const option = e.target.closest('.scare-option');
        if (!option) return;
        const level = option.getAttribute('data-level');
        if (level) this._handleScareToggle(level);
      });
    }

    // Reset All Discoveries
    const btnResetAll = document.getElementById('btn-reset-all');
    const resetConfirm = document.getElementById('reset-confirm');
    const btnResetYes = document.getElementById('btn-reset-yes');
    const btnResetNo = document.getElementById('btn-reset-no');

    if (btnResetAll && resetConfirm) {
      btnResetAll.addEventListener('click', () => {
        resetConfirm.classList.remove('hidden');
      });
    }

    if (btnResetYes) {
      btnResetYes.addEventListener('click', () => {
        this._resetAllDiscoveries();
        if (resetConfirm) resetConfirm.classList.add('hidden');
      });
    }

    if (btnResetNo) {
      btnResetNo.addEventListener('click', () => {
        if (resetConfirm) resetConfirm.classList.add('hidden');
      });
    }
  }
}

// ------------------------------------------------------------------
// Bootstrap
// ------------------------------------------------------------------

window.app = new App();

document.addEventListener('DOMContentLoaded', () => {
  window.app.init();
});
