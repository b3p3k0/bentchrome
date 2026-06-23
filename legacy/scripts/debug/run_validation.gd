extends SceneTree

## Standalone script to run validation checks
## Usage: godot --headless --script scripts/debug/run_validation.gd

func _init():
	print("🔍 Running validation checks...")

	# Load and run health check
	var health_check = preload("res://scripts/debug/health_check.gd").new()
	var health_passed = health_check.run_health_check()

	# Load and run code validator
	var code_validator = preload("res://scripts/debug/code_validator.gd").new()
	var validation_results = code_validator.validate_project()

	# Summary
	print("\n📊 VALIDATION SUMMARY:")
	print("Health Check: ", "✅ PASSED" if health_passed else "❌ FAILED")
	print("Code Violations: ", validation_results.violations.size())

	if health_passed and validation_results.violations.size() == 0:
		print("\n🎉 ALL VALIDATION CHECKS PASSED - NO REGRESSIONS DETECTED")
		quit(0)
	else:
		print("\n🚨 VALIDATION FAILED - REGRESSIONS DETECTED")
		quit(1)