#!/usr/bin/env python3
import subprocess
from pathlib import Path
from .utils import FolderChanger, run_and_return, escape_string_for_sourcepawn
from typing import Optional, NamedTuple


class VersionInfo(NamedTuple):
    tag: Optional[str]
    commit_number: int
    branch: str


def get_version_from_git(git_path: Path) -> VersionInfo:
    tag: Optional[str] = None
    commit_number: int
    branch: str
    try:
        from git import Repo
        repo = Repo(git_path)
        if len(repo.tags) < 1:
            tag = None
        else:
            # :TODO: this returns the last lag, not what you want when you have stashed changes
            # when stashed changes are present git describe returns something like "1.6.3-1-g00bac1b"
            # as the current tag, but this will only give us "1.6.3", the latest tag, equivalent to
            # "git describe --abbrev=0 --tags"
            tag = str(repo.tags[-1])
        commit_number = sum(1 for _ in repo.iter_commits())
        branch = str(repo.active_branch)
    except ImportError:
        with FolderChanger(git_path):
            commit_number = int(run_and_return(['git', 'rev-list', '--count', 'HEAD']))
            branch = run_and_return(['git', 'rev-parse', '--abbrev-ref', 'HEAD'])
            try:
                tag = run_and_return(['git', 'describe', '--tags', 'HEAD'])
            except subprocess.CalledProcessError as e:
                if e.returncode == 128:
                    tag = None
                else:
                    raise e
    return VersionInfo(tag, commit_number, branch)


def make_include(info: VersionInfo, tag_if_none_exists: str):
    return f"""\
#if defined _autoversioning_included
 #endinput
#endif
#define _autoversioning_included
#define AUTOVERSIONING_TAG "{escape_string_for_sourcepawn(info.tag if info.tag is not None else tag_if_none_exists)}"
#define AUTOVERSIONING_COMMIT "{escape_string_for_sourcepawn(str(info.commit_number))}"
"""
