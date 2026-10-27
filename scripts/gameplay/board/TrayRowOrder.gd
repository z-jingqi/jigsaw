extends RefCounted
## Preserve each row's reading order; only a balancing tail may cross rows.


static func remove_group(groups: Array, removed) -> void:
	var removed_index := groups.find(removed)
	if removed_index < 0:
		return
	var rows: Array = [[], []]
	for index in groups.size():
		if index != removed_index:
			rows[index % 2].append(groups[index])
	var remaining := groups.size() - 1
	var top_count := ceili(remaining / 2.0)
	if rows[0].size() > top_count:
		rows[1].append(rows[0].pop_back())
	elif rows[0].size() < top_count:
		rows[0].append(rows[1].pop_back())
	groups.clear()
	for column in top_count:
		groups.append(rows[0][column])
		if column < rows[1].size():
			groups.append(rows[1][column])
