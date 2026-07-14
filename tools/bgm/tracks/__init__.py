"""Track registry: bgm event name -> composition module. One module per
track; adding a track = one module + one row here (+ a MusicDirector TRACKS
row if it's a new scene)."""
from . import arena, menu, freeway, suburbs, snowy

TRACKS = {
    "bgm_menu": menu,
    "bgm_arena": arena,
    "bgm_freeway": freeway,
    "bgm_suburbs": suburbs,
    "bgm_snowy": snowy,
}
