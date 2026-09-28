export class WeatherAmbience {
  constructor() {
    this.context = null;
    this.enabled = false;
    this.lastScene = '';
    this.nextDetail = 0;
    this.lastMix = -1;
  }

  async enable() {
    if (!this.context) this.createAudio();
    if (!this.context) return false;
    try {
      await this.context.resume();
      this.enabled = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  disable() {
    this.enabled = false;
    if (!this.context) return;
    this.master.gain.setTargetAtTime(0, this.context.currentTime, 0.12);
  }

  createAudio() {
    const AudioContextClass = window.AudioContext || window.webkitAudioContext;
    if (!AudioContextClass) return;
    const audio = new AudioContextClass();
    const master = audio.createGain();
    master.gain.value = 0;
    master.connect(audio.destination);

    const noise = audio.createBuffer(1, audio.sampleRate * 4, audio.sampleRate);
    const samples = noise.getChannelData(0);
    let previous = 0;
    for (let index = 0; index < samples.length; index++) {
      const white = Math.random() * 2 - 1;
      previous = (previous + 0.025 * white) / 1.025;
      samples[index] = white * 0.55 + previous * 0.8;
    }

    const makeNoise = (type, frequency) => {
      const source = audio.createBufferSource();
      source.buffer = noise;
      source.loop = true;
      const filter = audio.createBiquadFilter();
      filter.type = type;
      filter.frequency.value = frequency;
      const gain = audio.createGain();
      gain.gain.value = 0;
      source.connect(filter).connect(gain).connect(master);
      source.start();
      return gain;
    };

    this.context = audio;
    this.master = master;
    this.wind = makeNoise('lowpass', 360);
    this.rain = makeNoise('highpass', 950);
    this.distantRain = makeNoise('bandpass', 560);
    this.noise = noise;
  }

  chirp(time, frequency, duration, volume, shape = 'sine') {
    const audio = this.context;
    const tone = audio.createOscillator();
    const envelope = audio.createGain();
    tone.type = shape;
    tone.frequency.setValueAtTime(frequency, time);
    tone.frequency.exponentialRampToValueAtTime(frequency * 1.22, time + duration * 0.35);
    tone.frequency.exponentialRampToValueAtTime(frequency * 0.88, time + duration);
    envelope.gain.setValueAtTime(0.0001, time);
    envelope.gain.exponentialRampToValueAtTime(volume, time + 0.025);
    envelope.gain.exponentialRampToValueAtTime(0.0001, time + duration);
    tone.connect(envelope).connect(this.master);
    tone.start(time);
    tone.stop(time + duration + 0.01);
  }

  thunder(time) {
    const audio = this.context;
    const source = audio.createBufferSource();
    source.buffer = this.noise;
    const filter = audio.createBiquadFilter();
    filter.type = 'lowpass';
    filter.frequency.setValueAtTime(190, time);
    filter.frequency.exponentialRampToValueAtTime(75, time + 2.8);
    const envelope = audio.createGain();
    envelope.gain.setValueAtTime(0.0001, time);
    envelope.gain.linearRampToValueAtTime(0.45, time + 0.18);
    envelope.gain.exponentialRampToValueAtTime(0.0001, time + 3.2);
    source.connect(filter).connect(envelope).connect(this.master);
    source.start(time);
    source.stop(time + 3.3);
  }

  update(scene, night, blindFraction) {
    if (!this.context) return;
    const audio = this.context;
    const now = audio.currentTime;
    if (now - this.lastMix < 0.12) return;
    this.lastMix = now;
    const openness = Math.max(0, 1 - blindFraction);
    const volume = this.enabled && !document.hidden ? 0.035 + 0.12 * openness : 0;
    this.master.gain.setTargetAtTime(volume, now, 0.18);
    const wind = {
      despejado: 0.07, nublado: 0.17, lluvia: 0.12, tormenta: 0.28,
      niebla: 0.09, frío: 0.27, calor: 0.07,
    }[scene] ?? 0.08;
    const rain = scene === 'tormenta' ? 0.37 : scene === 'lluvia' ? 0.27 : 0;
    this.wind.gain.setTargetAtTime(wind, now, 0.55);
    this.rain.gain.setTargetAtTime(rain, now, 0.55);
    this.distantRain.gain.setTargetAtTime(rain * 0.2, now, 0.55);
    if (!this.enabled || document.hidden || now < this.nextDetail) return;
    const audibleScene = night && !['lluvia', 'tormenta'].includes(scene) ? 'noche' : scene;
    if (audibleScene !== this.lastScene) {
      this.lastScene = audibleScene;
      this.nextDetail = now + 0.5;
      return;
    }
    if (audibleScene === 'despejado' || audibleScene === 'nublado') {
      this.chirp(now, 1650, 0.2, 0.18);
      this.chirp(now + 0.24, 1950, 0.17, 0.13);
      this.nextDetail = now + (audibleScene === 'despejado' ? 5 : 9) + Math.random() * 4;
    } else if (audibleScene === 'noche') {
      for (let index = 0; index < 3; index++) {
        this.chirp(now + index * 0.14, 3200, 0.09, 0.045, 'triangle');
      }
      this.nextDetail = now + 2 + Math.random() * 2;
    } else if (audibleScene === 'calor') {
      this.chirp(now, 2850, 0.75, 0.045, 'triangle');
      this.nextDetail = now + 1.7 + Math.random() * 2;
    } else if (audibleScene === 'tormenta') {
      this.thunder(now);
      this.nextDetail = now + 11 + Math.random() * 9;
    } else if (audibleScene === 'lluvia' || audibleScene === 'niebla') {
      this.chirp(now, 670, 0.07, 0.06);
      this.nextDetail = now + 2 + Math.random() * 3;
    } else {
      this.nextDetail = now + 4;
    }
  }
}
