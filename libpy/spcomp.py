from typing import Optional, Type, Callable, Iterable
from types import TracebackType
from pathlib import Path, PurePath
import sys
import os


def get_most_relevant_frame(traceback: TracebackType) -> TracebackType:
    """
        Predicting the most relevant frame from a traceback is quite hard/impossible,
        but this is probably the best thing to do in most cases.
    :param traceback: A traceback object
    :return: The traceback frame furthest from the originating one that is still on the same file
    """
    originating_script = Path(traceback.tb_frame.f_code.co_filename)
    while traceback.tb_next is not None and \
            Path(traceback.tb_next.tb_frame.f_code.co_filename).samefile(originating_script):
        traceback = traceback.tb_next

    return traceback


class SpcompExceptionHandler:
    def __init__(self, message: Optional[str]):
        self.message = message
        self.previous_handler: \
            Optional[Callable[[Type[BaseException], BaseException, TracebackType], None]] = None

    @staticmethod
    def get_most_relevant_frame(traceback: TracebackType) -> TracebackType:
        """
            Predicting the most relevant frame from a traceback is quite hard/impossible,
            but this is probably the best thing to do in most cases.
        :param traceback: A traceback object
        :return: The traceback frame furthest from the originating one that is still on the same file
        """
        originating_script = Path(traceback.tb_frame.f_code.co_filename)
        while traceback.tb_next is not None and \
                Path(traceback.tb_next.tb_frame.f_code.co_filename).samefile(originating_script):
            traceback = traceback.tb_next

        return traceback

    def __call__(self, _type: Type[BaseException], value: BaseException, traceback: TracebackType) -> None:
        relevant_frame = SpcompExceptionHandler.get_most_relevant_frame(traceback)

        line = relevant_frame.tb_lineno
        file = Path(relevant_frame.tb_frame.f_code.co_filename).absolute()
        notice = f"{self.message}: " if self.message is not None else ""
        print(f"{file}:({line}) : error 0: {notice}{_type.__name__}: {value.args}")
        pass

    def activate(self) -> bool:
        if sys.excepthook is not self:
            self.previous_handler = sys.excepthook
            sys.excepthook = self
            return True
        else:
            return False

    def restore(self) -> bool:
        if self.previous_handler is not None:
            sys.excepthook = self.previous_handler
            return True
        else:
            return False


def get_compiler_filename() -> PurePath:
    return PurePath("spcomp" + ".exe" if os.name == "nt" else "")


def get_compiler_from_include(include_path: Path) -> Optional[Path]:
    compiler_candidate: Path = include_path.parent / get_compiler_filename()
    if not compiler_candidate.exists():
        return None
    if os.access(str(compiler_candidate), os.X_OK):
        return compiler_candidate
    else:
        return None
