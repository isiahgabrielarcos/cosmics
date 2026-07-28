extends Node

# Ports the audio loading block of main.lua.
# play_music("lightSpeedChase") / play_sfx("laserSound") / set_master_volume(0.75)

const MUSIC := {
	"lightSpeedChase":      "res://assets/audio/music/aLightSpeedChaseFinal.mp3",
	"cosmicLobby":          "res://assets/audio/music/cosmicLobbyFinal.mp3",
	"cosmicVillage":        "res://assets/audio/music/extendedCosmicVillage.mp3",
	"cosmicEntrance":       "res://assets/audio/music/cosmicEntrance.mp3",
	"outsideTheVillage":    "res://assets/audio/music/outsideTheVillageFinal.mp3",
	"gameOverMusic":        "res://assets/audio/music/gameOverMusic.mp3",
	"missionCompleteMusic": "res://assets/audio/music/missionDoneMusic.mp3",
}

const SFX := {
	# Weapons
	"laserSound":            "res://assets/audio/sfx/laserSound.mp3",
	"cometProjectile":       "res://assets/audio/sfx/cometProjectile.mp3",
	"switchWeapon":          "res://assets/audio/sfx/switchWeapon.mp3",
	"weapon5Shoot":          "res://assets/audio/sfx/weapon5Shoot.mp3",
	"weapon6Shoot":          "res://assets/audio/sfx/weapon6Shoot.mp3",
	"laserBeamSkill":        "res://assets/audio/sfx/laserBeamSkill.mp3",
	"invincibleSkill":       "res://assets/audio/sfx/invincibleSkill.mp3",
	# Modules
	"skill1Sound":           "res://assets/audio/sfx/skill1SoundEffect.mp3",
	"shockWaveSound":        "res://assets/audio/sfx/shockWaveSound.mp3",
	"electricShockSound":    "res://assets/audio/sfx/electricShockSound.mp3",
	"shockWaveSoundDef":     "res://assets/audio/sfx/shockWaveSoundDef.mp3",
	"electricShockSoundDef": "res://assets/audio/sfx/electricShockSoundDef.mp3",
	# Enemies
	"enemyDeath":            "res://assets/audio/sfx/alienDeath.mp3",
	"bossSpawnSound":        "res://assets/audio/sfx/bossDeathSound.mp3",
	"bossDeathSound":        "res://assets/audio/sfx/bossSound2.mp3",
	"explosionSound":        "res://assets/audio/sfx/explosionSound.mp3",
	# BG
	"demoWarning":           "res://assets/audio/sfx/demoWarning.mp3",
	# Items
	"moduleChest":           "res://assets/audio/sfx/moduleChest.mp3",
	"cosmicShards":          "res://assets/audio/sfx/cosmicShards.mp3",
	# Hero
	"dashSoundEffect":       "res://assets/audio/sfx/dashSoundEffect.mp3",
	"tobyEscaped":           "res://assets/audio/sfx/tobyEscaped.mp3",
	"UFOsoaring":            "res://assets/audio/sfx/UFOsoaring.mp3",
	# UI
	"pauseSoundEffect":      "res://assets/audio/sfx/pauseSoundEffect.mp3",
	"pickedMode1":           "res://assets/audio/sfx/pickedMode.mp3",
	"pickedMode2":           "res://assets/audio/sfx/pickedMode2.mp3",
	"playGame":              "res://assets/audio/sfx/playGame.mp3",
	"switchMode":            "res://assets/audio/sfx/switchMode.mp3",
	"interacting":           "res://assets/audio/sfx/interacting.mp3",
	"missionComplete":       "res://assets/audio/sfx/missionComplete.mp3",
	"gameOverSound":         "res://assets/audio/sfx/deathSound.mp3",
	"levelUp":               "res://assets/audio/sfx/levelUp.mp3",
}

const SFX_POOL_SIZE := 12

var master_volume: float = 0.75   # `volume = .75` in main.lua
var music_volume: float = 0.5     # channel-1 volume in main.lua

var _music_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_next: int = 0
var _streams: Dictionary = {}
var current_music: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # audio keeps working while paused

	_music_player = AudioStreamPlayer.new()
	_music_player.bus = "Master"
	add_child(_music_player)

	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_sfx_pool.append(p)

	set_master_volume(master_volume)


func _get_stream(path: String) -> AudioStream:
	if not _streams.has(path):
		_streams[path] = load(path)
	return _streams[path]


# ── Music ──────────────────────────────────────────────────────────────────────

func play_music(name: String, loop: bool = true) -> void:
	if not MUSIC.has(name):
		push_warning("AudioManager: unknown music '%s'" % name)
		return
	if current_music == name and _music_player.playing:
		return
	var stream: AudioStream = _get_stream(MUSIC[name])
	if stream is AudioStreamMP3:
		stream.loop = loop
	_music_player.stream = stream
	_music_player.volume_db = linear_to_db(music_volume)
	_music_player.play()
	current_music = name


func stop_music() -> void:
	_music_player.stop()
	current_music = ""


# ── SFX ────────────────────────────────────────────────────────────────────────

func play_sfx(name: String) -> void:
	if not SFX.has(name):
		push_warning("AudioManager: unknown sfx '%s'" % name)
		return
	var p := _sfx_pool[_sfx_next]
	_sfx_next = (_sfx_next + 1) % SFX_POOL_SIZE
	p.stream = _get_stream(SFX[name])
	p.play()


# ── Volume ─────────────────────────────────────────────────────────────────────

func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	var bus := AudioServer.get_bus_index("Master")
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master_volume, 0.0001)))
