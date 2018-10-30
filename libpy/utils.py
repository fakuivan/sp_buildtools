#!/usr/bin/env python3
import os
import subprocess
import json
from typing import Union, Sequence, Iterator, Tuple, List
from pathlib import Path, PurePosixPath


def path_walk(top: Path, topdown=False, followlinks=False) -> \
        Iterator[Tuple[Path, Iterator[Path], Iterator[Path]]]:
    """
         See Python docs for os.walk, exact same behavior but it yields Path() instances instead
    """
    names: List[Path] = list(top.iterdir())

    dirs = (node for node in names if node.is_dir() is True)
    nondirs = (node for node in names if node.is_dir() is False)

    if topdown:
        yield top, dirs, nondirs

    for name in dirs:
        if followlinks or name.is_symlink() is False:
            for x in path_walk(name, topdown, followlinks):
                yield x

    if topdown is not True:
        yield top, dirs, nondirs


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


def escape_string_for_sourcepawn(_input: str) -> str:
    # From https://stackoverflow.com/a/14945097
    # Not completely safe nor extensively tested
    return json.dumps(_input)[1:-1]


def run_and_return(argv: Sequence[str]) -> str:
    text = subprocess.check_output(args=argv)
    if str != bytes:
        text = str(text, 'utf-8')
    return text.strip()


class FolderChanger:
    def __init__(self, folder: Union[bytes, str, Path]) -> None:
        self.old = os.getcwd()
        self.new: Union[bytes, str] = folder if isinstance(folder, Path) else str(folder)

    def __enter__(self) -> None:
        if self.new:
            os.chdir(self.new)

    def __exit__(self, type, value, traceback) -> None:
        os.chdir(self.old)
