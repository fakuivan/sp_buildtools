#!/usr/bin/env bash

find_string_at_index () {
	local collection=("${@:2}")
	local to_find="$1"
	local element_index
	for element_index in "${!collection[@]}"; do 
		if [[ "${collection[element_index]}" == "$to_find" ]]; then
			echo "$element_index"
			return 0
		fi
	done
	return 1
}
