extends Node
## Sfx — 全局音效与音乐总线接口（autoload）。
##
## 依赖 addons/sound_manager 插件提供的 SoundManager 单例。
## 集中管理音效路径常量与 BGM 切换策略，方便后续替换资源。
##
## 用法：
##   Sfx.play("step")               # 普通 SFX → SFX 总线
##   Sfx.play_ui("ui_click")        # UI SFX → UI 总线
##   Sfx.play_bgm("game", 1.0)      # 切歌带 1s crossfade
##   Sfx.attach_ui(some_control)    # 把节点子树内全部 Button 自动挂上 ui_click

const _SFX_PATHS := {
	"step":           "res://assets/sounds/step.sfxr",
	"push":           "res://assets/sounds/push.sfxr",
	"undo":           "res://assets/sounds/undo.mp3",
	"crate_done":     "res://assets/sounds/crate_done.sfxr",
	"level_complete": "res://assets/sounds/level_complete.sfxr",
}

const _UI_SFX_PATHS := {
	"ui_click":       "res://assets/sounds/ui_click.mp3",
}

const _BGM_PATHS := {
	"menu":           "res://assets/sounds/menu_music.mp3",
	"game":           "res://assets/sounds/game_music.mp3",
}

# 每个 SFX 可附带默认 pitch / volume 微调
const _SFX_PITCH := {
	"step":           1.0,
	"push":           0.85,   # 比 step 沉一些
	"undo":           1.0,
	"crate_done":     1.0,
	"level_complete": 1.0,
	"ui_click":       1.0,
}

var _cache: Dictionary = {}            # path -> AudioStream
var _current_bgm_key: String = ""
var _sm: Node = null                   # SoundManager autoload reference

func _ready() -> void:
	_sm = get_node_or_null("/root/SoundManager")
	if _sm == null:
		push_warning("[Sfx] SoundManager autoload missing; audio playback will be no-op")

# --- SFX (gameplay) ---

func play(name: String) -> void:
	if _sm == null: return
	var stream := _load_sfx(name, _SFX_PATHS)
	if stream == null: return
	var p: AudioStreamPlayer = _sm.play_sound(stream)
	if p != null:
		p.pitch_scale = _SFX_PITCH.get(name, 1.0)

# --- SFX (UI bus) ---

func play_ui(name: String) -> void:
	if _sm == null: return
	var stream := _load_sfx(name, _UI_SFX_PATHS)
	if stream == null: return
	var p: AudioStreamPlayer = _sm.play_ui_sound(stream)
	if p != null:
		p.pitch_scale = _SFX_PITCH.get(name, 1.0)

# --- BGM ---

func play_bgm(key: String, crossfade: float = 1.0) -> void:
	if _sm == null: return
	if key == _current_bgm_key:
		return
	var path: String = _BGM_PATHS.get(key, "")
	if path == "":
		push_warning("[Sfx] unknown bgm key: %s" % key)
		return
	var stream := _load_sfx(key, _BGM_PATHS)
	if stream == null:
		return
	_ensure_bgm_loops(stream)
	_sm.play_music(stream, crossfade)
	_current_bgm_key = key

func stop_bgm(fade: float = 0.5) -> void:
	if _sm == null: return
	_sm.stop_music(fade)
	_current_bgm_key = ""

# --- helpers ---

func _load_sfx(name: String, table: Dictionary) -> AudioStream:
	var path: String = table.get(name, "")
	if path == "":
		push_warning("[Sfx] unknown sfx: %s" % name)
		return null
	var stream: AudioStream = _cache.get(path) as AudioStream
	if stream == null:
		stream = load(path) as AudioStream
		if stream == null:
			push_warning("[Sfx] failed to load sfx: %s" % path)
			return null
		_cache[path] = stream
	return stream

func _ensure_bgm_loops(stream: AudioStream) -> void:
	if stream == null:
		return
	for prop_name in [&"loop", &"looping"]:
		if _has_property(stream, prop_name):
			stream.set(prop_name, true)

func _has_property(obj: Object, prop_name: StringName) -> bool:
	for prop in obj.get_property_list():
		if StringName(prop.get("name", "")) == prop_name:
			return true
	return false

# --- UI auto-binding ---

## 遍历 root 子树，把所有 Button 的 pressed 信号挂上 ui_click。
## 节点上若已挂过则跳过（用 meta 标记）。
func attach_ui(root: Node) -> void:
	if root == null: return
	_attach_ui_recursive(root)

func _attach_ui_recursive(node: Node) -> void:
	if node is Button:
		var btn: Button = node
		if not btn.has_meta("_sfx_attached"):
			btn.set_meta("_sfx_attached", true)
			btn.pressed.connect(func(): play_ui("ui_click"))
	for child in node.get_children():
		_attach_ui_recursive(child)
