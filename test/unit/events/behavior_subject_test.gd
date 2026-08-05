extends GutTest

func test_has_no_value_before_emit() -> void:
	var subject := BehaviorSubject.new()

	assert_false(subject.has_value())

func test_get_value_and_has_value_after_emit() -> void:
	var subject := BehaviorSubject.new()

	subject.emit("hello")

	assert_true(subject.has_value())
	assert_eq(subject.get_value(), "hello")

func test_subscribe_without_prior_value_does_not_fire_immediately() -> void:
	var subject := BehaviorSubject.new()
	var received := []

	subject.subscribe(func(value): received.append(value))

	assert_eq(received.size(), 0)

func test_subscribe_with_prior_value_replays_immediately() -> void:
	var subject := BehaviorSubject.new()
	subject.emit("cached")
	var received := []

	subject.subscribe(func(value): received.append(value))

	assert_eq(received, ["cached"])

func test_emit_notifies_all_existing_subscribers() -> void:
	var subject := BehaviorSubject.new()
	var received_a := []
	var received_b := []
	subject.subscribe(func(value): received_a.append(value))
	subject.subscribe(func(value): received_b.append(value))

	subject.emit("update")

	assert_eq(received_a, ["update"])
	assert_eq(received_b, ["update"])
