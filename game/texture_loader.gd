class_name TextureLoader
extends RefCounted
## Loads an image from a res:// path — imported Texture2D first, then a raw
## Image.load fallback (relative, then globalized) for anything not imported —
## cached by path. One shared copy; the old build duplicated this across four
## UI scripts.

static var _cache: Dictionary = {}

static func load_texture(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var tex: Texture2D = null
	var res := ResourceLoader.load(path, "Texture2D")
	if res is Texture2D:
		tex = res
	else:
		var img := Image.new()
		var err := img.load(path)
		if err != OK:
			err = img.load(ProjectSettings.globalize_path(path))
		if err == OK:
			tex = ImageTexture.create_from_image(img)
	_cache[path] = tex
	return tex
