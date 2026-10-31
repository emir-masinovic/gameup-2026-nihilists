extends RefCounted

# The level supplies observed environmental evidence. No elapsed-time or marker gate:
# survey stress, clear fuel, then witness living vegetation or a wet patch recovering.
var problem_seen = false
var mitigation_done = false
var recovery_seen = false

func observe_problem() -> bool:
	if problem_seen:
		return false
	problem_seen = true
	return true

func record_mitigation() -> bool:
	if not problem_seen or mitigation_done:
		return false
	mitigation_done = true
	return true

func observe_recovery() -> bool:
	if not mitigation_done or recovery_seen:
		return false
	recovery_seen = true
	return true

func ready_for_clearing() -> bool:
	return problem_seen and mitigation_done and recovery_seen

func summary() -> String:
	if not problem_seen:
		return "Survey a dry or stressed part of the forest."
	if not mitigation_done:
		return "Make a firebreak: cut a tree and clear its stump."
	if not recovery_seen:
		return "Witness recovering vegetation or rain restoring dry ground."
	return "Return to the golden clearing."
