class_name ThemeProgressPolicyTest
extends GdUnitTestSuite

const ThemeProgressPolicyScript := preload(
	"res://scripts/runtime/presentation/ThemeProgressPolicy.gd"
)


func test_progress_boundaries() -> void:
	assert_int(ThemeProgressPolicyScript.build(0, 100).paw_count).is_equal(0)
	assert_int(ThemeProgressPolicyScript.build(20, 100).paw_count).is_equal(1)
	assert_int(ThemeProgressPolicyScript.build(21, 100).paw_count).is_equal(2)
	assert_int(ThemeProgressPolicyScript.build(80, 100).paw_count).is_equal(4)
	assert_int(ThemeProgressPolicyScript.build(81, 100).paw_count).is_equal(5)


func test_zero_total_is_not_complete() -> void:
	var model := ThemeProgressPolicyScript.build(0, 0)
	assert_bool(model.is_complete).is_false()
	assert_float(model.ratio).is_zero()
