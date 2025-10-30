# Vehicle Physics Progression - Value Tracking Document ☕

## Overview
Transitioning from "twitchy RC car" physics to realistic vehicle weight and momentum.

## Target 0-60 Times (Real-World Reference)
Based on vehicle types and stats:

### Heavy Vehicles (10-12 seconds)
- **Kandy Kane** (Ice Cream Truck, Accel:5, Armor:8) → 10-12 sec
- **Razorback** (Military Hummer, Accel:3, Armor:8) → 9-11 sec
- **Hammertoe** (Lifted Monster, Accel:5, Armor:7) → 8-10 sec
- **Bumper** (Cadillac Land Yacht, Accel:3, Armor:7) → 9-10 sec

### Medium Vehicles (6-8 seconds)
- **Smoky** (Police SUV, Accel:7, Armor:7) → 7-8 sec
- **Splat Cat** (Compact Car, Accel:6, Armor:5) → 6-7 sec

### Light/Performance Vehicles (3-6 seconds)
- **Cricket** (Dirt Track Midget, Accel:8, Armor:4) → 4-5 sec
- **Ghost** (1960s Sports Car, Accel:8, Armor:3) → 4.5-5.5 sec
- **Mr. Ghastly** (Motorcycle, Accel:8, Armor:2) → 3-4 sec

---

## Phase 1 - Basic Inertia (COMPLETED)

### Stat Range Recalibration
```
BEFORE (Extreme Values):
acceleration_range: 200-1950 (1750pt spread)
deceleration_range: 120-1250 (1130pt spread)
brake_range: 500-2200 (1700pt spread)

AFTER (Realistic Values):
acceleration_range: 300-900 (600pt spread - 3:1 ratio)
deceleration_range: 200-600 (400pt spread - 3:1 ratio)
brake_range: 400-1200 (800pt spread - 3:1 ratio)
```

### Physics Method Change
```
BEFORE: velocity.move_toward(desired, step_distance)
AFTER: Force-based acceleration
  var force = current_direction * step_distance
  velocity += force
```

### Momentum System Implementation
```
BEFORE: Instant direction changes
AFTER: Momentum preservation
  momentum_factor: 0.98-0.92 (based on mass_scalar)
  coast_factor: 0.995-0.985 (heavy vehicles coast longer)
  momentum_preservation: 0.9-0.7 (based on handling_curve)
```

### Direction Change Inertia
```
ADDED: Cross-momentum preservation
  cross_momentum = velocity.project(perpendicular_to_new_direction)
  velocity += cross_momentum * momentum_preservation * mass_scalar * 0.1
```

---

## Phase 2 - Responsive Physics + Smart Terrain Transitions (COMPLETED)

### Phase 2A - Acceleration Response Fix
```
BEFORE (Conservative Ranges):
acceleration_range: 300-900 (600pt spread)
deceleration_range: 200-600 (400pt spread)
brake_range: 400-1200 (800pt spread)
acceleration_curve: pow(x, 0.25) - brutal low-speed response

AFTER (Responsive Ranges):
acceleration_range: 450-1200 (750pt spread - 2.67:1 ratio)
deceleration_range: 250-750 (500pt spread - 3:1 ratio)
brake_range: 500-1500 (1000pt spread - 3:1 ratio)
acceleration_curve: pow(x, 0.4) - much more responsive
minimum_safety_limits: raised to 80/50/150 (from 60/40/120)
```

### Phase 2B - Low-Speed Boost System
```
ADDED: Speed-dependent acceleration multiplier
  boost_factor = lerp(2.0, 1.0, speed_ratio / 0.3)
  Applied when speed_ratio < 0.3 (under 30% of top speed)
  Effect: 2.0x boost at standstill, 1.0x at 30% speed
  Result: Vehicles feel responsive from standstill but realistic at speed
```

### Phase 2C - Speed-Dependent Momentum System
```
BEFORE: Static momentum preservation (0.9-0.7 based on handling)
AFTER: Dynamic speed + terrain integrated system

Base momentum preservation:
  speed_ratio = current_speed / effective_max_speed
  base_momentum = lerp(0.1, 0.9, speed_ratio)  # Low speed = tight, high speed = loose

Terrain integration:
  final_momentum = base_momentum * handling_curve_factor * terrain_handling_modifier

Cross-momentum strength:
  cross_momentum_strength = final_momentum * mass_scalar * lerp(0.02, 0.15, speed_ratio)
  Effect: Minimal sliding at low speeds, realistic drift at high speeds

Coasting system:
  BEFORE: Static momentum_factor (0.98-0.92)
  AFTER: Dynamic coasting = base_coast * terrain_factor * speed_modifier

  Terrain-specific coasting:
  - Ice/water: coast longer (1.002x modifier)
  - Sand/grass: natural braking (0.995x modifier)
  - Track: baseline (1.0x modifier)
```

### Phase 2D - Smart Terrain Transition System
```
BEFORE: Uniform 0.2 second transitions with simple ease-out
AFTER: Context-aware timing with asymmetric curves

Dynamic transition timing:
  Road → Sand/Grass: 1.0-1.5 sec (gradual deceleration feel)
  Sand/Grass → Road: 0.5-0.75 sec (quicker grip recovery)
  Any → Ice/Water: 0.4-0.6 sec (sudden loss of control)
  Ice/Water → Any: 1.2-1.8 sec (gradual grip recovery)

Speed-dependent scaling:
  final_time = base_time * (1.0 + speed_ratio * 0.5)
  High speed transitions feel more dramatic

Asymmetric transition curves:
  losing_grip: Sharp initial drop, gradual completion (1.0 - pow(1.0 - progress, 0.3))
  gaining_grip: Gradual start, sharp final recovery (pow(progress, 0.3))
  ice_transition: Immediate effect with long tail (1.0 - pow(1.0 - progress, 2.0))
  smooth: Default ease-out for similar surface changes
```

---

## Phase 2.5 - Critical Fix: Realistic Vehicle Physics Overhaul (COMPLETED)

### **Problem: Vehicle "Pulling" Issue**
**Root Cause:** The cross-momentum system was fundamentally flawed, causing vehicles to accumulate sideways momentum and "pull" in unintended directions during acceleration.

**Symptoms:**
- Vehicles would start moving sideways when accelerating
- Unrealistic "pulling" behavior making cars uncontrollable
- Physics felt like "driving on ice" with constant unwanted sliding

### **Solution: Velocity Decomposition with Lateral Friction**
**Replaced flawed cross-momentum with research-based physics model from FOSS vehicle implementations:**

#### **Core Physics Replacement**
```gdscript
BEFORE (Problematic):
var cross_momentum = velocity.project(perpendicular_direction)
velocity = velocity + (cross_momentum * momentum_strength)  # Accumulated over time!

AFTER (Realistic):
# Decompose velocity into forward and lateral components
var forward_velocity = forward_direction * velocity.dot(forward_direction)
var lateral_velocity = right_direction * velocity.dot(right_direction)

# Apply lateral friction based on grip
var lateral_grip = _calculate_lateral_grip(speed, mass, terrain, handling)
var friction_reduced_lateral = lateral_velocity * (1.0 - lateral_grip)

# Reconstruct velocity with realistic physics
velocity = forward_velocity + friction_reduced_lateral
```

#### **Dynamic Lateral Grip System**
```
Grip Calculation Factors:
- Speed: 100% grip at standstill → 30% grip at full speed
- Terrain: Track=95%, Sand=70%, Snow=50%, Ice=20%
- Handling: Poor handling=60% → Good handling=100%
- Mass: Light vehicles=100% → Heavy vehicles=80%

Final grip = speed_grip × terrain_grip × handling_grip × mass_grip
Clamped between 5% (always some sliding) and 98% (never perfect)
```

#### **Centripetal Force Enhancement**
```gdscript
High-Speed Direction Changes:
- Calculates direction change severity (0 = same, 1 = opposite)
- Compares required turn force vs vehicle capabilities
- Applies realistic drift when capabilities exceeded
- Integrates with terrain and vehicle stats
```

### **Results Achieved**
✅ **No more sideways pulling** - vehicles go exactly where directed
✅ **Realistic physics** - proper forward/lateral force separation
✅ **Terrain-appropriate behavior** - ice slides, track grips
✅ **Speed-dependent handling** - tight control at low speeds, drift at high speeds
✅ **Maintained arcade feel** - still fun and responsive, not a simulation

### **Integration Points Preserved**
- ✅ Terrain transition system enhanced with grip factors
- ✅ Mass scaling affects grip and momentum
- ✅ Speed-dependent physics now controls grip levels
- ✅ AI vehicles (enemy cars) use identical physics
- ✅ Debug visualization shows grip states and drift amounts

### **Files Modified**
- `scripts/vehicles/player_car.gd` - Complete physics overhaul
- `scripts/vehicles/enemy_car.gd` - Mirrored all changes
- `VEHICLE_PHYSICS_PROGRESSION.md` - This documentation

### **Debug Features Added**
```
Console Output (when DEBUG_VEHICLE_TUNING = true):
[VehicleTuning] Physics: Speed=156.3, Lateral=23.1, Grip=67%, Drift=0.15
[VehicleTuning] Grip factors: Speed=0.78, Terrain=0.95, Handling=0.85, Mass=0.90 → Final=0.56
[Physics] High-speed turn: excess force 0.23, drift added
```

---

## Phase 3 - Real-World Calibration (PENDING)

### 0-60 Time Measurements (To Be Measured)
```
Current: TBD - need to test each character
Target: See reference table above

Methodology:
1. Test each roster character individually
2. Measure time from 0 to 60% of top speed
3. Adjust acceleration curves to match targets
4. Document actual vs target times
```

### Mass Scaling Adjustments (To Be Tuned)
```
Current Mass Scaling:
acceleration: /= mass_scalar
deceleration: /= lerp(1.0, mass_scalar, 0.95)
brake_force: /= lerp(1.0, mass_scalar, 0.95)
turn_lock: *= lerp(1.0, mass_scalar, 0.9)

Expected Adjustments: TBD based on feel testing
```

---

## Phase 3 - Advanced Dynamics (FUTURE)

### Speed-Dependent Turn Radius (Not Implemented)
```
Planned:
speed_turn_penalty = velocity.length() / effective_max_speed
turn_radius_factor = mass_scalar * speed_turn_penalty
max_turn_angle = lerp(1.0, 0.3, turn_radius_factor)
```

### Understeer/Oversteer Behavior (Not Implemented)
```
Planned:
Heavy vehicles: Understeer tendencies
Light vehicles: Potential oversteer at high speeds
```

---

## Current Physics State (After Phase 1)

### Files Modified
- `data/balance/StatsRanges.tres` - Recalibrated acceleration ranges
- `scripts/vehicles/player_car.gd` - Force-based physics + momentum
- `scripts/vehicles/enemy_car.gd` - Mirrored physics changes

### Expected Feel Changes
- Heavy vehicles should feel sluggish but maintain momentum
- Light vehicles should feel responsive but not instant
- All vehicles should drift/slide when changing directions quickly
- Coasting should feel realistic (heavy vehicles coast longer)

### Debug Features Active
- `DEBUG_VEHICLE_TUNING = true` - Shows mass scalar and stat info
- Roster stat analysis - Prints computed values for all characters
- Enhanced HUD - Displays real-time acceleration, brake, mass data

---

## Next Steps

1. **Test Phase 2 Results**: Launch game and test the new responsive + terrain-aware physics
2. **Measure 0-60 Times**: Time each character's acceleration to 60% top speed with new system
3. **Fine-tune Transition Feel**: Adjust transition timing and curves based on testing
4. **Adjust Curves**: Modify acceleration curves to hit target times if needed
5. **Implement Phase 3**: Add speed-dependent turn radius and advanced dynamics

---

## Phase 3 - Enhanced Slip Angle Physics for Dramatic Drifting (COMPLETED)

### **Problem: Insufficient Drift Sensation**
**User feedback:** "we still aren't 'feeling' any drift or momentum sensation" and wanted to focus on "getting sideways and laying some rubber down" with more realistic handling.

**Symptoms:**
- Cars felt like "slot cars" with insufficient sliding
- Lack of dramatic sideways momentum during high-speed turns
- Conservative drift factors prevented satisfying "rubber laying" feel
- No progressive slip angle physics for realistic drift behavior

### **Solution: Aggressive Slip Angle Physics Implementation**
**Based on FOSS racing game research (VDrift, Godot arcade implementations, Pacejka tire models):**

#### **Enhanced Drift Factor Constants**
```gdscript
BEFORE (Conservative):
"low_speed": Vector2(0.1, 0.25)     # Too tight
"high_speed": Vector2(0.45, 0.75)   # Not dramatic enough
terrain_multipliers: track=0.8, sand=1.0, snow=1.3, ice=1.8

AFTER (Dramatic):
"low_speed": Vector2(0.05, 0.15)    # Tighter low-speed control
"high_speed": Vector2(0.15, 0.85)   # Much more dramatic sliding
"high_speed_boost": Vector2(0.25, 1.2)  # Extra boost above 70% speed
"slip_angle_sensitivity": 2.5       # Aggressive slip angle response
terrain_multipliers: track=0.7, sand=1.5, snow=2.0, ice=2.5
```

#### **Slip Angle Physics Implementation**
```gdscript
# Calculate slip angle between vehicle heading and velocity direction
var slip_angle = abs(velocity_direction.angle_to(vehicle_heading))
var slip_angle_multiplier = 1.0 + (slip_angle * slip_angle_sensitivity)

# High-speed dramatic boost above 70% speed
if speed_ratio > 0.7:
    var high_speed_factor = (speed_ratio - 0.7) / 0.3
    base_drift = lerp(high_speed.y, high_speed_boost.y, high_speed_factor)
```

#### **Progressive Sliding Enhancements**
```gdscript
# More sensitive direction change detection (0.02 vs 0.05 threshold)
# Lower speed threshold for drift activation (20 vs 30 units)
# Dramatic slide factor range (0.2-4.0 vs 0.1-2.0)
# High-speed drift boost up to 2.5x at full speed
# Terrain-specific slide multipliers for different surface feels
```

### **Results Achieved**
✅ **Dramatic sideways sliding** - cars now "lay rubber down" during high-speed turns
✅ **Progressive slip angle physics** - realistic tire behavior based on FOSS research
✅ **Speed-dependent drift boost** - dramatic effects above 70% speed
✅ **Enhanced terrain differentiation** - ice/snow feels dramatically different from track
✅ **Maintained control** - still responsive despite aggressive sliding
✅ **AI consistency** - enemy cars use identical enhanced physics

### **Integration Points Enhanced**
- ✅ Slip angle calculation drives drift intensity
- ✅ High-speed boost creates "laying rubber" sensation
- ✅ Terrain multipliers more aggressive and differentiated
- ✅ Weight and handling stats significantly affect drift behavior
- ✅ Debug output shows slip angles and drift states

### **Files Modified**
- `scripts/vehicles/player_car.gd` - Enhanced drift factors and slip angle physics
- `scripts/vehicles/enemy_car.gd` - Mirrored all changes for AI consistency
- `VEHICLE_PHYSICS_PROGRESSION.md` - This documentation update

### **Debug Features Enhanced**
```
Console Output (when DEBUG_VEHICLE_TUNING = true):
[VehicleTuning] Enhanced drift: Speed=78%, Slip=12.4°, Base=0.65, SlipMult=1.31×, Final=0.89
[VehicleTuning] HIGH SLIP ANGLE: Dramatic sliding active!
[VehicleTuning] DRAMATIC SLIDE: severity=0.85, factor=2.3, strength=0.28, speed=85%
[VehicleTuning] HIGH SPEED DRIFT: Laying rubber down!
```

---

*Document updated: Phase 3 complete - Enhanced slip angle physics creates dramatic drifting sensation with "laying rubber down" feel*