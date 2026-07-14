"""Track registry: bgm event name -> composition module. One module per
track; adding a track = one module + one row here (+ a MusicDirector TRACKS
row if it's a new scene)."""
from . import arena

TRACKS = {
    "bgm_arena": arena,
}
