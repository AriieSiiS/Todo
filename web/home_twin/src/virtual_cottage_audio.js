const SOUND_LABELS = {
  sfx_cottage_rain_loop: 'Lluvia',
  SFX_Blizzard_Moderate_Loop: 'Nieve',
  SFX_Wind_Exterior_Loop_02: 'Viento',
  SFX_Thunderstorm_Loop: 'Tormenta',
  SFX_Birds_Loop: 'Pájaros',
  SFX_Cicadas_Loop: 'Cigarras',
  SFX_Fireplace_Loop: 'Chimenea',
};

const EFFECT_LABELS = {
  Cat_Purr: 'Ronroneo',
  Dog_Bark: 'Ladrido',
  lamp_click: 'Clic de lámpara',
  'timer down': 'Temporizador',
};

const GROUP_LABELS = { base: 'Juego base', dlc: 'LØNÆR', dreemeDLC: 'Dreeme' };

export class VirtualCottageAudio {
  constructor(button, panel, muteButton) {
    this.button = button;
    this.panel = panel;
    this.muteButton = muteButton;
    this.muted = false;
    this.resumeMusicAfterMute = false;
    this.effectPlayers = new Set();
    this.catalog = null;
    this.soundPlayers = new Map();
    this.soundVolumes = new Map();
    this.music = new Audio();
    this.music.preload = 'metadata';
    this.music.volume = 0.55;
    this.trackIndex = 0;
    this.shuffle = false;
    this.autoWeather = true;
    this.weather = { scene: 'despejado', night: false, blind: 1 };
    this.music.addEventListener('ended', () => this.next());
    this.music.addEventListener('timeupdate', () => this.updateProgress());
    this.music.addEventListener('loadedmetadata', () => this.updateProgress());
    this.music.addEventListener('error', () => this.status('No se pudo reproducir esta pista.'));
    this.button.addEventListener('click', () => this.togglePanel());
    this.muteButton.addEventListener('click', () => this.setMuted(!this.muted));
  }

  setMuted(value) {
    if (value === this.muted) return;
    if (value) {
      this.resumeMusicAfterMute = !this.music.paused;
      this.music.pause();
      for (const player of this.soundPlayers.values()) player.pause();
      for (const player of this.effectPlayers) player.pause();
      this.effectPlayers.clear();
    }
    this.muted = value;
    this.music.muted = value;
    for (const player of this.soundPlayers.values()) player.muted = value;
    this.muteButton.setAttribute('aria-pressed', String(value));
    const label = value ? 'Activar todos los sonidos' : 'Silenciar todos los sonidos';
    this.muteButton.setAttribute('aria-label', label);
    this.muteButton.title = label;
    const playButton = this.panel.querySelector('#audio-play');
    if (playButton) playButton.textContent = value ? '▶' : this.resumeMusicAfterMute ? '⏸' : '▶';
    if (!value && this.catalog) {
      this.syncSounds();
      if (this.resumeMusicAfterMute) {
        this.music.play().catch(() => this.status('No se pudo reanudar la canción.'));
      }
      this.resumeMusicAfterMute = false;
    }
  }

  async togglePanel() {
    if (!this.catalog) {
      try {
        const response = await fetch('/audio/catalogo.json');
        if (!response.ok) throw new Error('Catálogo no disponible');
        this.catalog = await response.json();
        this.buildPanel();
      } catch (_) {
        this.button.textContent = 'Audio no disponible';
        return;
      }
    }
    this.panel.hidden = !this.panel.hidden;
    this.button.setAttribute('aria-expanded', String(!this.panel.hidden));
    if (!this.panel.hidden) this.syncSounds();
  }

  buildPanel() {
    const tracks = this.catalog.musica;
    const groups = Object.entries(GROUP_LABELS).map(([key, label]) => {
      const options = tracks.map((track, index) => ({ track, index }))
        .filter(({ track }) => track.grupo === key)
        .map(({ track, index }) => `<option value="${index}">${this.escape(track.nombre)}</option>`).join('');
      return `<optgroup label="${label}">${options}</optgroup>`;
    }).join('');
    const sounds = this.catalog.ambientes.map((item) => {
      this.soundPlayers.set(item.id, Object.assign(new Audio(item.ruta), { loop: true, preload: 'none', muted: this.muted }));
      this.soundVolumes.set(item.id, 0);
      return `<label class="audio-range"><span>${SOUND_LABELS[item.id] || this.escape(item.nombre)}</span><input type="range" min="0" max="100" value="0" data-sound="${item.id}" aria-label="Volumen de ${SOUND_LABELS[item.id] || this.escape(item.nombre)}"><output>0 %</output></label>`;
    }).join('');
    const effects = this.catalog.efectos.map((item) =>
      `<button type="button" data-effect="${item.id}">${EFFECT_LABELS[item.id] || this.escape(item.nombre)}</button>`
    ).join('');
    this.panel.innerHTML = `
      <div class="audio-heading"><strong>Música y ambiente</strong><button type="button" id="audio-close" aria-label="Cerrar panel">×</button></div>
      <p class="audio-source">Audio de Virtual Cottage instalado en este equipo</p>
      <section><h2>Música</h2><select id="audio-track" aria-label="Elegir canción">${groups}</select>
        <div class="audio-buttons"><button id="audio-previous" type="button" title="Pista anterior">⏮</button><button id="audio-play" type="button" title="Reproducir">▶</button><button id="audio-next" type="button" title="Siguiente pista">⏭</button><button id="audio-shuffle" type="button" aria-pressed="false" title="Orden aleatorio">⇄</button></div>
        <label class="audio-range"><span>Avance</span><input id="audio-progress" type="range" min="0" max="1000" value="0" aria-label="Avance de la canción"><output id="audio-time">0:00</output></label>
        <label class="audio-range"><span>Volumen musical</span><input id="audio-music-volume" type="range" min="0" max="100" value="55"><output>55 %</output></label>
      </section>
      <section><h2>Ambientes</h2><label class="audio-auto"><input id="audio-auto-weather" type="checkbox" checked> Seguir el clima de la ventana</label><div id="audio-sounds">${sounds}</div></section>
      <section><h2>Efectos breves</h2><div class="audio-effects">${effects}</div></section>
      <p id="audio-status" role="status"></p>`;
    this.panel.querySelector('#audio-close').addEventListener('click', () => this.togglePanel());
    this.panel.querySelector('#audio-track').addEventListener('change', (event) => this.selectTrack(Number(event.target.value), true));
    this.panel.querySelector('#audio-play').addEventListener('click', () => this.toggleMusic());
    this.panel.querySelector('#audio-previous').addEventListener('click', () => this.previous());
    this.panel.querySelector('#audio-next').addEventListener('click', () => this.next());
    this.panel.querySelector('#audio-shuffle').addEventListener('click', (event) => {
      this.shuffle = !this.shuffle;
      event.currentTarget.setAttribute('aria-pressed', String(this.shuffle));
    });
    this.panel.querySelector('#audio-music-volume').addEventListener('input', (event) => {
      this.music.volume = Number(event.target.value) / 100;
      event.target.nextElementSibling.textContent = `${event.target.value} %`;
    });
    this.panel.querySelector('#audio-progress').addEventListener('change', (event) => {
      if (Number.isFinite(this.music.duration)) this.music.currentTime = this.music.duration * Number(event.target.value) / 1000;
    });
    this.panel.querySelector('#audio-auto-weather').addEventListener('change', (event) => {
      this.autoWeather = event.target.checked;
      if (this.autoWeather) this.applyWeather();
    });
    this.panel.querySelectorAll('[data-sound]').forEach((slider) => slider.addEventListener('input', () => {
      this.autoWeather = false;
      this.panel.querySelector('#audio-auto-weather').checked = false;
      this.soundVolumes.set(slider.dataset.sound, Number(slider.value) / 100);
      slider.nextElementSibling.textContent = `${slider.value} %`;
      this.syncSounds();
    }));
    this.panel.querySelectorAll('[data-effect]').forEach((button) => button.addEventListener('click', async () => {
      if (this.muted) return;
      const effect = this.catalog.efectos.find((item) => item.id === button.dataset.effect);
      if (!effect) return;
      const player = new Audio(effect.ruta);
      player.volume = 0.65;
      player.muted = this.muted;
      this.effectPlayers.add(player);
      player.addEventListener('ended', () => this.effectPlayers.delete(player), { once: true });
      try { await player.play(); } catch (_) {
        this.effectPlayers.delete(player);
        this.status('No se pudo reproducir el efecto.');
      }
    }));
    this.selectTrack(0, false);
    this.applyWeather();
  }

  escape(value) {
    return value.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
  }

  status(value) {
    const label = this.panel.querySelector('#audio-status');
    if (label) label.textContent = value;
  }

  selectTrack(index, play) {
    if (!this.catalog?.musica[index]) return;
    this.trackIndex = index;
    this.music.src = this.catalog.musica[index].ruta;
    if (play && this.muted) {
      this.resumeMusicAfterMute = false;
      this.setMuted(false);
    }
    this.panel.querySelector('#audio-track').value = String(index);
    this.panel.querySelector('#audio-play').textContent = play ? '⏸' : '▶';
    this.status(this.catalog.musica[index].nombre);
    if (play) this.music.play().catch(() => this.status('No se pudo reproducir la canción.'));
  }

  async toggleMusic() {
    if (this.muted) {
      this.resumeMusicAfterMute = true;
      this.setMuted(false);
      return;
    }
    if (this.music.paused) {
      try { await this.music.play(); } catch (_) { this.status('No se pudo reproducir la canción.'); return; }
    } else {
      this.music.pause();
    }
    this.panel.querySelector('#audio-play').textContent = this.music.paused ? '▶' : '⏸';
  }

  next() {
    const count = this.catalog.musica.length;
    const index = this.shuffle ? Math.floor(Math.random() * count) : (this.trackIndex + 1) % count;
    this.selectTrack(index, true);
  }

  previous() {
    this.selectTrack((this.trackIndex - 1 + this.catalog.musica.length) % this.catalog.musica.length, true);
  }

  updateProgress() {
    const progress = this.panel.querySelector('#audio-progress');
    if (!progress) return;
    const duration = this.music.duration;
    progress.value = Number.isFinite(duration) && duration > 0 ? String(Math.round(this.music.currentTime / duration * 1000)) : '0';
    const time = Math.floor(this.music.currentTime);
    this.panel.querySelector('#audio-time').textContent = `${Math.floor(time / 60)}:${String(time % 60).padStart(2, '0')}`;
  }

  updateWeather(scene, night, blind) {
    const last = this.weather;
    if (last.scene === scene && last.night === night && last.blind === blind) return;
    this.weather = { scene, night, blind };
    if (this.catalog && this.autoWeather && (last.scene !== scene || last.night !== night)) this.applyWeather();
    else if (this.catalog) this.syncSounds();
  }

  applyWeather() {
    if (!this.catalog) return;
    const { scene, night } = this.weather;
    const levels = {
      despejado: { SFX_Birds_Loop: night ? 0 : 0.35, SFX_Cicadas_Loop: night ? 0.28 : 0 },
      nublado: { SFX_Birds_Loop: 0.15, SFX_Wind_Exterior_Loop_02: 0.1 },
      lluvia: { sfx_cottage_rain_loop: 0.55 },
      tormenta: { SFX_Thunderstorm_Loop: 0.55 },
      frío: { SFX_Blizzard_Moderate_Loop: 0.35, SFX_Wind_Exterior_Loop_02: 0.15 },
      calor: { SFX_Cicadas_Loop: 0.4, SFX_Birds_Loop: 0.1 },
      niebla: { SFX_Wind_Exterior_Loop_02: 0.13 },
    }[scene] || {};
    for (const item of this.catalog.ambientes) {
      if (item.id === 'SFX_Fireplace_Loop') continue;
      const value = levels[item.id] || 0;
      this.soundVolumes.set(item.id, value);
      const slider = this.panel.querySelector(`[data-sound="${item.id}"]`);
      slider.value = String(Math.round(value * 100));
      slider.nextElementSibling.textContent = `${slider.value} %`;
    }
    this.syncSounds();
  }

  syncSounds() {
    for (const [id, player] of this.soundPlayers) {
      if (this.muted) {
        player.pause();
        continue;
      }
      const outside = id !== 'SFX_Fireplace_Loop';
      const attenuation = outside ? 0.25 + 0.75 * (1 - this.weather.blind) : 1;
      player.volume = Math.min(1, (this.soundVolumes.get(id) || 0) * attenuation);
      if (player.volume > 0.001) {
        if (player.paused) player.play().catch(() => this.status('No se pudo reproducir un ambiente.'));
      } else if (!player.paused) {
        player.pause();
      }
    }
  }
}
