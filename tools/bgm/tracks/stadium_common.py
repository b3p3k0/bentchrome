"""Shared musical DNA for the Goliath pair: one chord progression (E with the
Bb tritone snarl), two tempos. p1 rings it as a doom stomp, p2 gallops the
same changes at double time — the phase flip reads as the SAME song enraged,
not a channel change.
"""

# the progression both phases walk: E / G / E / Bb->A
CHORDS = ["E2", "G2", "E2", "Bb2", "A2"]

# p1: long rings over a 4-bar (64-step) tile
DOOM = [
    (0, 14, "E2", 1.0), (16, 14, "G2", 1.0),
    (32, 14, "E2", 1.0), (48, 7, "Bb2", 1.0), (56, 7, "A2", 0.95),
]
DOOM_BASS = [
    (0, 6, "E1", 1.0), (8, 6, "E2", 0.85), (16, 6, "G2", 1.0), (24, 6, "G2", 0.85),
    (32, 6, "E1", 1.0), (40, 6, "E2", 0.85), (48, 7, "Bb2", 1.0), (56, 7, "A2", 0.95),
]

# p2: the same changes as a 2-bar (32-step) gallop
RAGE = [
    (0, 2, "E2", 1.0), (2, 2, "E2", 0.75), (4, 2, "E2", 0.9), (6, 2, "E2", 0.75),
    (8, 2, "G2", 1.0), (10, 2, "G2", 0.8), (12, 4, "E2", 0.95),
    (16, 2, "E2", 1.0), (18, 2, "E2", 0.75), (20, 2, "E2", 0.9), (22, 2, "E2", 0.75),
    (24, 2, "Bb2", 1.0), (26, 2, "Bb2", 0.85), (28, 4, "A2", 1.0),
]
