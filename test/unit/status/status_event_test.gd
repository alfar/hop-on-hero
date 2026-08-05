extends GutTest

func test_constructor_sets_type_and_amount() -> void:
	var event := StatusEvent.new("physical_damage", 42.0)

	assert_eq(event.type, "physical_damage")
	assert_eq(event.amount, 42.0)
