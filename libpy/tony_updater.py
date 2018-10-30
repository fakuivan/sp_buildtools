#!/usr/bin/env python3
from pathlib import Path, PurePosixPath
from .utils import escape_string_for_sourcepawn, path_walk
from typing import Callable, Optional, Iterable
from .vdf import VDFDict


def make_include(url: str) -> str:
    return f"""\
#if defined _updater_helper_included
 #endinput
#endif
#define _updater_helper_included
#define UPDATER_HELPER_URL "{escape_string_for_sourcepawn(url)}"
"""


class RemoteToPathFormatter:
    def __init__(self, local_root: Path, remote_root: PurePosixPath):
        """
        :param local_root:  This Path should be replaced by your local root directory.
        :param remote_root: This PurePosixPath should be put instead of the local root.
        """
        self.local_root = local_root
        self.remote_root = remote_root

    def format(self, local_path: Path) -> PurePosixPath:
        """
        Removes the local root for a given directory

        :param local_path: This path will have its local root folder swapped by the remote one.
        :return:           Path formatted as part of the remote root
        """
        return self.remote_root.joinpath(PurePosixPath(self.strip_local(local_path)))

    def strip_local(self, local_path: Path) -> Path:
        """
        Removes the local root for a given directory

        :param local_path:  The directory to remove its root (relative to ``remote_root``)
        :return:            Directory without root part
        """
        return local_path.relative_to(self.local_root)


FileTypeMapper = Callable[[Path, Path], Optional[str]]


def file_type_mapper_sm(file: Path, root: Path) -> Optional[str]:
    return "Source" if file.relative_to(root).parts[0] == "scripting" else "Plugin"


def file_type_mapper_mod(file: Path, root: Path) -> Optional[str]:
    # TODO: What would happen if the paths differ by case on windows?
    return "Plugin" if file.relative_to(root).parts[0:1] != ("addons", "sourcemod") else None


def build_vdf(sm_path: Path,
              notes: Iterable[str],
              version: str,
              sm_mapper: FileTypeMapper=file_type_mapper_sm,
              mod_path: Optional[Path]=None,
              mod_mapper: FileTypeMapper=file_type_mapper_mod) -> VDFDict:
    # https://gist.github.com/nosoop/6f699546ee6df7730d99395691fbbd8a
    info_section = VDFDict({
        "Version": {
            "Latest": str(version)
        }
    })
    for note in notes:
        info_section["Notes"] = note

    files_section = VDFDict()

    # To not repeat the logic for finding files on the mod and sm directories
    # we do a for loop for the sm and mod roots
    for mapper, formatter in \
            [(sm_mapper, RemoteToPathFormatter(sm_path, PurePosixPath("Path_SM")))] \
            + [] if mod_path is None else \
            [(mod_mapper, RemoteToPathFormatter(mod_path, PurePosixPath("Path_Mod")))]:
        for root, dirs, files in path_walk(formatter.local_root):
            for file in files:
                file = root.joinpath(file)
                _type = mapper(file, formatter.local_root)
                if _type is None:
                    continue
                files_section[_type] = str(formatter.format(file))

    return VDFDict({
        "Updater": {
            "Information": info_section
        },
        "Files": files_section
    })
