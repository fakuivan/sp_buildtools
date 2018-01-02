#!/usr/bin/env bash

# Imports
SPBB_SCRIPT_DIR="$(dirname "$0")"
source "$SPBB_SCRIPT_DIR/tools/git.sh"
source "$SPBB_SCRIPT_DIR/tools/output.sh"
source "$SPBB_SCRIPT_DIR/tools/misc.sh"

# Argument parsing

get_args () {
	local set_root=0
	local set_comp=0
	local set_help=0
	PACKAGE_SKIP_CLEANUP=0
	while getopts ":c:r:o:sh" option; do
		case $option in
			"s")
				PACKAGE_SKIP_CLEANUP=1
				;;
			"c")
				set_comp=1
				COMP_ROOT=$OPTARG
				;;
			"r")
				set_root=1
				PROJECT_ROOT=$OPTARG
				;;
			"o")
				PARSED_BUILD_OPTION=$OPTARG
				;;
			"h")
				set_help=1
				;;
		esac
	done
	if [[ set_help -eq 1 ]] || [[ ! set_root -eq 1 ]] || [[ ! set_comp -eq 1 ]]; then
		echo "Usage: $BASH_SOURCE -c [compiler directory] -r [project root] -s -o [build option]"
		return 1
	fi
	return 0
}

resolve_args () {
	if [[ ! -d $PROJECT_ROOT ]]; then
		return 1
	fi
	if [[ ! -d $COMP_ROOT ]]; then
		return 2
	fi
	if [[ ! -x $COMP_COMPILER_PATH ]]; then
		return 3
	fi
	local build_option_exists
	local build_option
	build_option="$(find_string_at_index "$PARSED_BUILD_OPTION" "${PROJECT_BUILD_OPTIONS[@]}")"
	build_option_exists=$?
	if [[ ! $build_option_exists -eq 0 ]]; then
		if [[ ! ${#PROJECT_BUILD_OPTIONS[@]} -gt 0 ]]; then
			# If no build options are available, skip errors for this argument
			BUILD_OPTION="-1"
		else
			return 4
		fi
	fi
	BUILD_OPTION="$build_option"
	return 0
}

# Main procedures

main () {
	get_args "$@"
	if [[ ! $? -eq 0 ]]; then
		return 1
	fi

	# Import project info
	if [[ ! -d $PROJECT_ROOT ]]; then
		logger_simple_error "Root project path '$(format_underline $PROJECT_ROOT)' is not a valid directory." 1
		return 3
	fi

	PROJECT_CONFIG_FILE="$PROJECT_ROOT/spbb_config.sh"
	## Everyday bash hackery
	local import_config_error_file=$(mktemp)
	local import_config_error_code
	source "$PROJECT_CONFIG_FILE" >"$import_config_error_file" 2>&1
	import_config_error_code=$?
	logger "Failed to import project configuration from '$(format_underline $PROJECT_CONFIG_FILE)'" \
		 "$(cat "$import_config_error_file")" $import_config_error_code 1
	if [[ ! $import_config_error_code -eq 0 ]]; then
		return 2
	fi

	# Globals

	UPDATER_SCRIPTS_PATH="$PROJECT_BUILDTOOLS_PATH/tony_updater"
	VERSION_SCRIPTS_PATH="$PROJECT_BUILDTOOLS_PATH/versioning"

	resolve_args
	case $? in
		1) return 3
		;;
		2) logger_simple_error "Compiler directory '$(format_underline $COMP_ROOT)' is not a valid directory." 1; return 4
		;;
		3) logger_simple_error "Failed to find a valid executable on '$(format_underline $COMP_COMPILER_PATH)' to use as compiler." 1; return 5
		;;
		4) logger_simple_error "'$(format_underline $PARSED_BUILD_OPTION)' is not a valid build option." 1; return 6
		;;
	esac

	BUILD_STEP=1

	logger "- Build process started for project '$(format_underline $PROJECT_SHORTNAME)'" "" "" 1
	logger "Gathering version from git repository on the project root..."
	local version_error="Failed to get version info from git:"
	get_version
	case $? in
		1) logger_simple_error "$version_error Current directory does not contain a valid git repository"; return 7
		;;
		2) logger_simple_error "$version_error Failed to detect git for command line installed on your system"; return 8
		;;
	esac
	logger "Done. Version: '$VERSION'."; ((step++))

	create_package_root
	if [[ ! $? -eq 0 ]]; then return 9; fi
	((BUILD_STEP++))

	build_version_include
	if [[ ! $? -eq 0 ]]; then return 10; fi
	((BUILD_STEP++))

	build_updater_include
	if [[ ! $? -eq 0 ]]; then return 11; fi
	((BUILD_STEP++))
	
	build_updater_manifest
	if [[ ! $? -eq 0 ]]; then return 12; fi
	((BUILD_STEP++))

	compile
	if [[ ! $? -eq 0 ]]; then return 13; fi
	((BUILD_STEP++))

	archive
	if [[ ! $? -eq 0 ]]; then return 14; fi
	((BUILD_STEP++))

	if [[ ! PACKAGE_SKIP_CLEANUP -eq 1 ]]; then
		cleanup
		if [[ ! $? -eq 0 ]]; then return 15; fi
	fi

	logger "- Build process successfully completed for project '$(format_underline $PROJECT_SHORTNAME)'" "" "" 1
}

get_version () {
	local error_code
	git_is_dir_repo "$PROJECT_ROOT"
	error_code=$?
	if [[ ! $error_code -eq 0 ]]; then
		return $error_code
	fi
	VERSION_TAG="$(git_get_latest_tag "$PROJECT_ROOT")"
	VERSION_COMMIT="$(git_get_commit_number "$PROJECT_ROOT")"
	VERSION="$(project_format_version_string "$VERSION_TAG" "$VERSION_COMMIT")"
}

create_package_root () {
	logger "Creating package root and copying directories..."
	if [[ -d "$PACKAGE_ROOT_PATH" ]]; then
		# We won't bother resolving this situation, let the user delete the folder
		logger_simple_error "Package directory already exists, please delete it first."
		return 1
	fi

	logger "Failed to make root package directory on '$(format_underline "$PACKAGE_ROOT_PATH")'." \
		"$(mkdir -p "$PACKAGE_BINARY_FILES" 2>&1 >/dev/null)" $?
	if [[ ! $? -eq 0 ]]; then return 2; fi

	logger "Failed to make binary package directory on '$(format_underline "$PACKAGE_BINARY_FILES")'." \
		"$(mkdir -p "$PACKAGE_BINARY_FILES" 2>&1 >/dev/null)" $?
	if [[ ! $? -eq 0 ]]; then return 3; fi

	for directory in "${PACKAGE_COPY_DIRS[@]}"
	do
		logger "Failed to copy directory '$(format_underline "$directory")'." \
			"$(cp -r "$directory" "$PACKAGE_ROOT_PATH" 2>&1 >/dev/null)" $?
		if [[ ! $? -eq 0 ]]; then return 4; fi
	done
	logger "Done.";
}

build_version_include () {
	logger "Building versioning include..."
	logger "Failed to generate updater includes." \
		"$(python3 "$VERSION_SCRIPTS_PATH/versioner.py" \
			"$PROJECT_ROOT" \
			"$PACKAGE_PROJECT_SPECIFIC_INCLUDES" \
			"$VERSION_TAG" 2>&1 >/dev/null)" $?
	if [[ ! $? -eq 0 ]]; then return 1; fi
	logger "Done.";
}

build_updater_include () {
	logger "Building updater include..."
	logger "Failed to generate version includes." \
		"$(python3 "$UPDATER_SCRIPTS_PATH/updater_link_helper.py" \
			--include_dir "$PACKAGE_PROJECT_SPECIFIC_INCLUDES" \
			--url "$(updater_format_manifest_url)" 2>&1 >/dev/null)" $?
	if [[ ! $? -eq 0 ]]; then return 1; fi
	logger "Done."; 
}

build_updater_manifest () {
	logger "Building updater manifest..."
	local release_notes; IFS=$'\n' read -d '' -r -a release_notes <<< "$(updater_format_notes $VERSION)"; unset IFS
	logger "Failed to build updater manifest." \
		"$(python3 "$UPDATER_SCRIPTS_PATH/updater_script_gen.py" \
			--sm_path "$PACKAGE_ROOT_PATH" \
			--version "$VERSION" \
			--notes "${release_notes[@]}" \
			--output "$PACKAGE_ROOT_PATH/$UPDATER_MANIFEST_PATH" 2>&1 >/dev/null)" $?
	if [[ ! $? -eq 0 ]]; then return 1; fi
	logger "Done.";
}

compile () {
	logger "Compiling source files..."
	local original_build_step="$BUILD_STEP"
	BUILD_STEP="$original_build_step][1"
	logger "Running pre-compile scripts..."
	comp_func_pre
	if [[ ! $? -eq 0 ]]; then return 1; fi
	logger "Done."
	for file_index in "${!COMP_PLUGINS[@]}"
	do
		BUILD_STEP="$original_build_step][2][$file_index"
		local file="${COMP_PLUGINS[$file_index]}"
		logger "Compiling '$(format_underline "$file")'..."
		local extra_arguments="$(comp_format_extra_arguments)"
		# If we don't define this before calling the compiler, the exit code goes to 💩
		local compilation_result_message
		local compilation_result
		local extra_arguments; IFS=$'\n' read -d '' -r -a extra_arguments <<< "$(comp_format_extra_arguments)"; unset IFS

		compilation_result_message="$("$COMP_COMPILER_PATH" \
			"$file" \
			"${COMP_INCLUDE_DIRS[@]/#/-i}" \
			"-o$(comp_format_output_file "$file")" \
			"${extra_arguments[@]}")"
		compilation_result=$?
		if [[ ! $compilation_result -eq 0 ]]; then
			logger "Failed to compile source file '$(format_underline "$file")'"
			logger "Error message: "
			logger "$(format_redcolor "$compilation_result_message")" "" "" 1
			logger "Exit code: $compilation_result"
			return 2
		else
			logger "Succesfully compiled file '$(format_underline "$file")'"
			logger "Output: "
			logger "$(format_greencolor "$compilation_result_message")" "" "" 1
		fi
	done
	BUILD_STEP="$original_build_step][3"
	logger "Running post-compile scripts..."
	comp_func_post
	if [[ ! $? -eq 0 ]]; then return 3; fi
	logger "Done."
	BUILD_STEP="$original_build_step"
	logger "Done."
	return 0
}

archive () {
	local saved_cwd="$(pwd)"
	logger "Archiving package..."

	local archive_path="$(package_format_archive_path $VERSION_TAG $VERSION_COMMIT)"
	if [[ -f "$archive_path" ]]; then
		logger_simple_error "Failed to create archive on path '$(format_underline "$archive_path")', file already exists. "
		return 2
	fi
	logger "Failed to archive package to '$(format_underline "$archive_path")'." \
		"$(
			relative_archive_path="$(readlink -f "$archive_path")"; \
			$(exit $?) && cd "$PACKAGE_ROOT_PATH" 2>&1 >/dev/null && zip -qr $relative_archive_path . \
		)" $?

	if [[ ! $? -eq 0 ]]; then
		return 1
	fi

	logger "Done."
	return 0
}

cleanup () {
	local step="$1"
	logger "Cleaning up..."
	logger "Failed to delete root package directory '$(format_underline "$PACKAGE_ROOT_PATH")''" \
		"$(rm -rf "$PACKAGE_ROOT_PATH"  2>&1 >/dev/null)" $?
	if [[ ! $? -eq 0 ]]; then
		return 1
	fi
	logger "Done."
}

main "$@"
exit $?
