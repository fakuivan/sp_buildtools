#!/usr/bin/env bash

# Output

logger_subtask () {
	local step="$BUILD_STEP"
	local subtask="$1"
	local description="$2"
	local error_message="$3"
	local error_code="$4"
	logger "$description" "$error_message" "$error_code" "" "$step][$subtask"
	return $?
}

logger_simple_error ()
{
	local step="$BUILD_STEP"
	local description="$1"
	local dont_use_tags="$2"
	if [[ ! "$dont_use_tags" -eq 1 ]]; then
		logger_subtask "Error" "$description"
		return $?
	else
		logger "$description" "" "" 1
		return $?
	fi
}

logger_debug_info () { 
	local message="$1"
	local call_stack=("${FUNCNAME[@]:1}")
	local call_tag="$(printf %b:: ${call_stack[@]})"
	echo "[${call_tag}][DEBUG] $message"
}

logger () {
	local step="$BUILD_STEP"
	local description="$1"
	local error_message="$2"
	local error_code="$3"
	local dont_use_tags="$4"
	local custom_step="$5"
	local tags
	local is_error=0
	local second_tag
	if ! ( [[ -z "$error_code" ]] && [[ -z "$error_message" ]] ); then second_tag="[Error]"; is_error=1; fi
	if ! [[ -z "$custom_step" ]]; then step="$custom_step"; fi

	if [[ ! "$error_code" -eq 0 ]] || [[ ! "$is_error" -eq 1 ]]; then
		if [[ ! "$dont_use_tags" -eq 1 ]]; then tags="[$step]$second_tag "; fi
		echo "${tags}$description"
		if [[ "$is_error" -eq 1 ]]; then
			echo "${tags}Error message: $(format_redcolor $error_message). Error code: $error_code."
		fi
	fi
	if [[ -z "$error_code" ]]; then error_code=0; fi
	return $error_code
}

# Output format

FORMAT_RESET=$(tput sgr0)

format_underline () {
	echo "$(tput smul)$@${FORMAT_RESET}"
}

format_redcolor () {
	echo "$(tput setaf 1)$@${FORMAT_RESET}"
}

format_greencolor () {
	echo "$(tput setaf 2)$@${FORMAT_RESET}"
}
