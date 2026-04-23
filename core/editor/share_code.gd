class_name ShareCode
extends RefCounted
## ShareCode — 关卡分享码编解码。
##
## 格式：`Base64URL( gzip( JSON ) ) + "-" + CRC32_HEX`
##
## - 用于在聊天/论坛粘贴；UI 一键复制/粘贴
## - CRC32 校验放在尾部 8 个 hex 字符（小写），与 base64 用单个 `-` 分隔
##   （base64url 允许 `-` 和 `_`，但 `-` 用作分隔时位于"尾段"，与 base64 内可能出现的 `-` 通过"最后一个连字符"规则区分）
##
## 注：Godot 4 的 PackedByteArray.compress() 默认 Zstd；这里改用 GZIP 兼容跨平台。

static func encode_level(level: Level) -> String:
	var json := LevelLoader.to_json(level, false)
	return encode_json(json)

static func encode_json(json: String) -> String:
	var raw: PackedByteArray = json.to_utf8_buffer()
	var compressed: PackedByteArray = raw.compress(FileAccess.COMPRESSION_GZIP)
	var b64: String = Marshalls.raw_to_base64(compressed)
	# 转 base64url
	b64 = b64.replace("+", "-").replace("/", "_").rstrip("=")
	var crc := _crc32(raw)
	return "%s-%08x" % [b64, crc]

## 解码：返回 { ok: bool, json: String, error: String }
static func decode(code: String) -> Dictionary:
	var s := code.strip_edges()
	if s.is_empty():
		return { "ok": false, "error": "empty code" }
	var dash := s.rfind("-")
	if dash < 0 or s.length() - dash - 1 != 8:
		return { "ok": false, "error": "missing CRC suffix" }
	var b64u := s.substr(0, dash)
	var crc_hex := s.substr(dash + 1, 8)
	# base64url -> base64 + padding
	var b64 := b64u.replace("-", "+").replace("_", "/")
	var pad := (4 - (b64.length() % 4)) % 4
	for i in pad:
		b64 += "="
	var compressed: PackedByteArray = Marshalls.base64_to_raw(b64)
	if compressed.is_empty():
		return { "ok": false, "error": "invalid base64" }
	var raw: PackedByteArray = compressed.decompress_dynamic(-1, FileAccess.COMPRESSION_GZIP)
	if raw.is_empty():
		return { "ok": false, "error": "decompress failed" }
	var crc_real: int = _crc32(raw)
	var crc_expect: int = ("0x" + crc_hex).hex_to_int()
	if crc_real != crc_expect:
		return { "ok": false, "error": "CRC mismatch" }
	var json := raw.get_string_from_utf8()
	if json == "":
		return { "ok": false, "error": "utf8 decode failed" }
	return { "ok": true, "json": json }

## 解码并构造 Level；失败返回 null。
static func decode_to_level(code: String) -> Level:
	var r := decode(code)
	if not bool(r.get("ok", false)):
		push_warning("[ShareCode] decode failed: %s" % r.get("error", "?"))
		return null
	return LevelLoader.parse_json(r.get("json", ""))

# ---------- CRC32 ----------

static var _crc_table: PackedInt64Array = PackedInt64Array()

static func _ensure_table() -> void:
	if not _crc_table.is_empty():
		return
	_crc_table.resize(256)
	for i in 256:
		var c: int = i
		for _k in 8:
			if (c & 1) != 0:
				c = (c >> 1) ^ 0xEDB88320
			else:
				c = c >> 1
		_crc_table[i] = c

static func _crc32(data: PackedByteArray) -> int:
	_ensure_table()
	var c: int = 0xFFFFFFFF
	for i in data.size():
		var b: int = data[i]
		c = (c >> 8) ^ int(_crc_table[(c ^ b) & 0xFF])
	return c ^ 0xFFFFFFFF
