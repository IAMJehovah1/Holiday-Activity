"""
SoC Cooldown Sequence for iPad Pro M2.

Runs a configurable idle countdown before a heavy agent task, giving the
Apple M2 chip time to reach a stable thermal baseline.  All output is
written to *stdout* so it can be captured in tests.

Usage (standalone)::

    python -m repo_sorter cooldown --duration 30

Usage (programmatic)::

    from repo_sorter.cooldown import run_cooldown
    run_cooldown(duration=20, label="Pre-fetch cooldown")
"""

import sys
import time
from typing import Optional, TextIO


# ---------------------------------------------------------------------------
# ANSI helpers (same style as cli.py)
# ---------------------------------------------------------------------------

_RESET = "\033[0m"
_BOLD = "\033[1m"
_CYAN = "\033[36m"
_GREEN = "\033[32m"
_YELLOW = "\033[33m"
_BLUE = "\033[34m"


def _supports_color(stream: TextIO = sys.stdout) -> bool:
    return hasattr(stream, "isatty") and stream.isatty()


def _c(text: str, code: str, stream: TextIO = sys.stdout) -> str:
    if _supports_color(stream):
        return f"{code}{text}{_RESET}"
    return text


# ---------------------------------------------------------------------------
# Cooldown sequence
# ---------------------------------------------------------------------------

_SPINNER = ("⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏")


def run_cooldown(
    duration: int = 30,
    label: str = "SoC Cooldown",
    verbose: bool = False,
    *,
    _stream: Optional[TextIO] = None,
    _tick: float = 1.0,
) -> None:
    """
    Run an idle cooldown countdown.

    Parameters
    ----------
    duration:
        Total seconds to wait (default 30).  A value of 0 skips the wait
        and prints the ready banner immediately.
    label:
        Display name shown in the header line.
    verbose:
        When True, print one status line per second instead of using an
        in-place overwrite (useful for non-interactive / CI output).
    _stream:
        Output stream; defaults to ``sys.stdout``.  Exposed for testing.
    _tick:
        Seconds per iteration; exposed for testing (set to 0 to skip
        ``time.sleep`` calls).
    """
    out = _stream or sys.stdout
    interactive = (not verbose) and _supports_color(out)

    header = _c(f"🧊  {label}", _BOLD + _CYAN, out)
    print(f"\n{header}\n", file=out)

    if verbose and duration > 0:
        print(
            _c(f"    Waiting {duration}s for M2 SoC to reach thermal baseline…", _YELLOW, out),
            file=out,
        )

    for remaining in range(duration, 0, -1):
        elapsed = duration - remaining
        spinner = _SPINNER[elapsed % len(_SPINNER)]
        mins, secs = divmod(remaining, 60)
        time_str = f"{mins:02d}:{secs:02d}" if mins else f"00:{secs:02d}"
        line = (
            f"    {_c(spinner, _BLUE, out)}  "
            f"{_c(time_str, _BOLD + _YELLOW, out)} remaining"
        )

        if interactive:
            # Overwrite the same line each tick
            print(f"\r{line}   ", end="", flush=True, file=out)
        else:
            print(line, file=out, flush=True)

        if _tick > 0:
            time.sleep(_tick)

    if interactive and duration > 0:
        # Clear the countdown line before printing the ready banner
        print("\r" + " " * 40 + "\r", end="", flush=True, file=out)

    ready = _c("✅  Ready — thermal baseline reached.", _BOLD + _GREEN, out)
    print(f"{ready}\n", file=out)
