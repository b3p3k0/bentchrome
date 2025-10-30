#!/usr/bin/env bash
set -euo pipefail

echo "Running Godot4 API quick validator..."

# Patterns that indicate Godot3 or deprecated APIs
patterns=(
  "Engine.get_physics_time\(" 
  "update\(" 
  "linear_interpolate\(" 
  "ExtResource\(" 
  "shape.extents"
)

fail=0
for p in "${patterns[@]}"; do
  echo "Checking for pattern: $p"
  if rg --hidden --glob '!node_modules' -n "$p" || true; then
    echo "Pattern $p possibly found (see above)."
    fail=1
  fi
done

if [ "$fail" -ne 0 ]; then
  echo "Validator: Deprecated API patterns found. Please review and fix before committing."
  exit 1
else
  echo "Validator: No obvious deprecated patterns found."
fi
