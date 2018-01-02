#!/usr/bin/env bash

git_is_dir_repo () {
	local path="$1"
	if [[ -x "$(command -v git)" ]]; then
		if [[ -d "$path/.git" ]] || git -C "$path" rev-parse --git-dir >/dev/null 2>&1; then
			return 0
		else
			return 1
		fi
	else 
		return 2
	fi
}

git_get_commit_number () {
	local path="$1"
	echo "$(git -C "$path" rev-list --count HEAD)"
	return $?
}

git_get_latest_tag () {
	local path="$1"
	local tag
	local error_code
	tag="$(git -C "$path" describe --tags 2>/dev/null)"
	error_code=$?
	if [[ $error_code -eq 0 ]]; then 
		echo "$tag"
	else 
		# Tag "0" should be treated as "No tag present in the repository"
		echo "0"
	fi
	return $error_code
}
