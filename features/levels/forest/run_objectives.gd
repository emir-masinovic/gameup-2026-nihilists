extends RefCounted

# The level supplies observed environmental evidence. No elapsed-time or marker gate:
# survey stress, clear fuel, then witness living vegetation or a wet patch recovering.
var regional_mode = false
var problem_seen = false
var mitigation_done = false
var recovery_seen = false

func observe_problem(region: String = "") -> bool:
	if regional_mode and region != "drylands":
		return false
	if problem_seen:
		return false
	problem_seen = true
	return true

func record_mitigation(region: String = "") -> bool:
	if regional_mode and region != "drylands":
		return false
	if not problem_seen or mitigation_done:
		return false
	mitigation_done = true
	return true

func observe_recovery(region: String = "") -> bool:
	if regional_mode and region != "wetlands":
		return false
	if not mitigation_done or recovery_seen:
		return false
	recovery_seen = true
	return true

func ready_for_clearing() -> bool:
	return problem_seen and mitigation_done and recovery_seen

func summary() -> String:
	if regional_mode:
		if not problem_seen:
			return "Berries and ponds replenish supplies. Take the west trail to Drylands and survey dry ground."
		if not mitigation_done:
			return "In Drylands, cut a tree and clear its stump: less fuel, less shade."
		if not recovery_seen:
			return "Return east through Forest to Wetlands. Visit the mint habitat north of camp and observe regrowth."
		return "Reach the golden refuge at the north edge of Wetlands."
	if not problem_seen:
		return "Survey a dry or stressed part of the forest."
	if not mitigation_done:
		return "Make a firebreak: cut a tree and clear its stump."
	if not recovery_seen:
		return "Witness recovering vegetation or rain restoring dry ground."
	return "Return to the golden clearing."
