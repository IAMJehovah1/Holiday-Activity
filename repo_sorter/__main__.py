"""Allow running the CLI as ``python -m repo_sorter``."""

import sys
from .cli import main

sys.exit(main())
