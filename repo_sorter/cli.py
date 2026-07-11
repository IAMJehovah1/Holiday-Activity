"""
Command-line interface for the medical repository sorting tool.

Usage
-----
    python -m repo_sorter <command> [options]

or, if installed via pip:

    repo-sorter <command> [options]

Run ``repo-sorter --help`` or ``repo-sorter <command> --help`` for details.
"""

import argparse
import json
import os
import sys
from typing import List, Optional

from .cooldown import run_cooldown
from .sorter import RepoSorter, _auto_categorize


# ---------------------------------------------------------------------------
# Formatting helpers
# ---------------------------------------------------------------------------

_RESET = "\033[0m"
_BOLD = "\033[1m"
_CYAN = "\033[36m"
_GREEN = "\033[32m"
_YELLOW = "\033[33m"
_GREY = "\033[90m"


def _supports_color() -> bool:
    return hasattr(sys.stdout, "isatty") and sys.stdout.isatty()


def _c(text: str, code: str) -> str:
    if _supports_color():
        return f"{code}{text}{_RESET}"
    return text


def _print_repo(repo: dict, verbose: bool = False) -> None:
    name = _c(repo["name"], _BOLD + _CYAN)
    category = _c(repo.get("category") or "—", _GREEN)
    tags = ", ".join(repo.get("tags") or []) or "—"
    desc = repo.get("description") or ""
    url = repo.get("url") or ""
    print(f"  {name}")
    print(f"    Category : {category}")
    print(f"    Tags     : {_c(tags, _YELLOW)}")
    if desc:
        print(f"    Desc     : {desc}")
    if url:
        print(f"    URL      : {_c(url, _GREY)}")
    if verbose and repo.get("metadata"):
        print(f"    Metadata : {json.dumps(repo['metadata'])}")
    print()


def _print_category_list(categories: dict) -> None:
    max_key = max((len(k) for k in categories), default=10)
    for key, desc in sorted(categories.items()):
        print(f"  {_c(key.ljust(max_key + 2), _BOLD + _GREEN)}  {desc}")


# ---------------------------------------------------------------------------
# Sub-command handlers
# ---------------------------------------------------------------------------

def _cmd_add(args: argparse.Namespace, sorter: RepoSorter) -> int:
    tags = [t.strip() for t in args.tags.split(",") if t.strip()] if args.tags else []
    metadata: dict = {}
    if args.metadata:
        try:
            metadata = json.loads(args.metadata)
        except json.JSONDecodeError as exc:
            print(f"Error: --metadata must be valid JSON. {exc}", file=sys.stderr)
            return 1

    category = args.category
    if not category and args.auto_categorize:
        category = _auto_categorize(args.description or "", [])
        if category:
            print(f"Auto-detected category: {_c(category, _GREEN)}")

    try:
        entry = sorter.add(
            name=args.name,
            url=args.url,
            description=args.description,
            category=category,
            tags=tags,
            metadata=metadata,
            overwrite=getattr(args, "overwrite", False),
        )
    except ValueError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    print(f"Added: {_c(entry['name'], _BOLD)}")
    return 0


def _cmd_remove(args: argparse.Namespace, sorter: RepoSorter) -> int:
    found = sorter.remove(args.name)
    if found:
        print(f"Removed: {args.name}")
    else:
        print(f"Not found: {args.name}", file=sys.stderr)
        return 1
    return 0


def _cmd_list(args: argparse.Namespace, sorter: RepoSorter) -> int:
    tags = [t.strip() for t in args.tags.split(",") if t.strip()] if args.tags else []
    repos = sorter.filter(
        category=args.category,
        tags=tags or None,
        search=args.search,
    )
    if not repos:
        print("No repositories found.")
        return 0
    print(f"\n{_c(f'Found {len(repos)} repository/repositories:', _BOLD)}\n")
    for repo in repos:
        _print_repo(repo, verbose=args.verbose)
    return 0


def _cmd_show(args: argparse.Namespace, sorter: RepoSorter) -> int:
    repo = sorter.get(args.name)
    if not repo:
        print(f"Not found: {args.name}", file=sys.stderr)
        return 1
    print()
    _print_repo(repo, verbose=True)
    return 0


def _cmd_update(args: argparse.Namespace, sorter: RepoSorter) -> int:
    fields: dict = {}
    if args.url is not None:
        fields["url"] = args.url
    if args.description is not None:
        fields["description"] = args.description
    if args.category is not None:
        fields["category"] = args.category
    if args.tags is not None:
        fields["tags"] = [t.strip() for t in args.tags.split(",") if t.strip()]
    if args.metadata is not None:
        try:
            fields["metadata"] = json.loads(args.metadata)
        except json.JSONDecodeError as exc:
            print(f"Error: --metadata must be valid JSON. {exc}", file=sys.stderr)
            return 1
    if not fields:
        print("Nothing to update. Provide at least one option.", file=sys.stderr)
        return 1
    try:
        entry = sorter.update(args.name, **fields)
    except KeyError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1
    print(f"Updated: {_c(entry['name'], _BOLD)}")
    return 0


def _cmd_tag(args: argparse.Namespace, sorter: RepoSorter) -> int:
    tags = [t.strip() for t in args.tags.split(",") if t.strip()]
    if not tags:
        print("Error: provide at least one tag.", file=sys.stderr)
        return 1
    try:
        if args.remove:
            entry = sorter.remove_tags(args.name, tags)
            verb = "Removed tags from"
        else:
            entry = sorter.add_tags(args.name, tags)
            verb = "Added tags to"
    except KeyError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1
    print(f"{verb} {_c(entry['name'], _BOLD)}: {', '.join(entry['tags']) or '(none)'}")
    return 0


def _cmd_categorize(args: argparse.Namespace, sorter: RepoSorter) -> int:
    try:
        entry = sorter.update(args.name, category=args.category)
    except KeyError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1
    print(
        f"Set category of {_c(entry['name'], _BOLD)} "
        f"to {_c(entry['category'], _GREEN)}"
    )
    return 0


def _cmd_categories(args: argparse.Namespace, sorter: RepoSorter) -> int:
    action = getattr(args, "cat_action", "list")
    if action == "list":
        cats = sorter.list_categories()
        print(f"\n{_c('Available categories:', _BOLD)}\n")
        _print_category_list(cats)
        print()
    elif action == "add":
        sorter.add_category(args.key, args.description)
        print(f"Category added: {_c(args.key, _GREEN)}")
    elif action == "remove":
        found = sorter.remove_category(args.key)
        if found:
            print(f"Category removed: {args.key}")
        else:
            print(
                f"Category '{args.key}' not found in custom categories.",
                file=sys.stderr,
            )
            return 1
    return 0


def _cmd_fetch(args: argparse.Namespace, sorter: RepoSorter) -> int:
    token = args.token or os.environ.get("GITHUB_TOKEN")
    print(f"Fetching repositories for '{args.username}' from GitHub…")
    try:
        repos = sorter.fetch_from_github(
            args.username,
            token=token,
            auto_categorize=not args.no_auto_categorize,
        )
    except RuntimeError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1
    print(f"Fetched {len(repos)} repositories.")
    if repos:
        print()
        for repo in repos:
            _print_repo(repo)
    return 0


def _cmd_export(args: argparse.Namespace, sorter: RepoSorter) -> int:
    try:
        sorter.export(args.output, fmt=args.format)
        print(f"Exported to {args.output} (format: {args.format})")
    except ValueError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1
    return 0


def _cmd_import(args: argparse.Namespace, sorter: RepoSorter) -> int:
    try:
        count = sorter.import_repos(args.input, overwrite=args.overwrite)
        print(f"Imported {count} repositories.")
    except (FileNotFoundError, json.JSONDecodeError) as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1
    return 0


def _cmd_cooldown(args: argparse.Namespace, sorter: RepoSorter) -> int:
    try:
        run_cooldown(
            duration=args.duration,
            label=args.label,
            verbose=args.verbose,
        )
    except ValueError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1
    return 0


# ---------------------------------------------------------------------------
# Parser construction
# ---------------------------------------------------------------------------

def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="repo-sorter",
        description=(
            "Medical Repository Sorting Tool — categorize, tag, and manage "
            "your GitHub repositories with a focus on healthcare projects."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
examples:
  # Add a repository manually
  repo-sorter add owner/my-ehr --category ehr --tags "fhir,hl7" \\
      --description "Electronic Health Record system"

  # Fetch all repos for a GitHub user and auto-categorize
  repo-sorter fetch octocat --token ghp_xxx

  # List all EHR repositories
  repo-sorter list --category ehr

  # List repositories tagged with 'fhir'
  repo-sorter list --tags fhir

  # Search by keyword
  repo-sorter list --search imaging

  # Change a repository's category
  repo-sorter categorize owner/my-ehr ehr

  # Add/remove tags
  repo-sorter tag owner/my-ehr --tags "fhir,hl7"
  repo-sorter tag owner/my-ehr --tags "hl7" --remove

  # Export to CSV
  repo-sorter export --output repos.csv --format csv

  # View all available categories
  repo-sorter categories list

  # Add a custom category
  repo-sorter categories add ai-health "AI/ML tools for healthcare"
""",
    )
    parser.add_argument(
        "--db",
        metavar="PATH",
        help="Path to the repository database file (default: ~/.repo_sorter/repos.json)",
    )

    sub = parser.add_subparsers(dest="command", metavar="<command>")
    sub.required = True

    # -- add -----------------------------------------------------------------
    p_add = sub.add_parser("add", help="Add a repository to the catalogue")
    p_add.add_argument("name", help='Repository name, e.g. "owner/repo"')
    p_add.add_argument("--url", help="GitHub URL")
    p_add.add_argument("--description", "-d", help="Short description")
    p_add.add_argument("--category", "-c", help="Category key (see 'categories list')")
    p_add.add_argument("--tags", "-t", help="Comma-separated list of tags")
    p_add.add_argument(
        "--metadata", "-m", help="Extra metadata as a JSON object, e.g. '{\"stars\":42}'"
    )
    p_add.add_argument(
        "--overwrite", action="store_true", help="Replace if already exists"
    )
    p_add.add_argument(
        "--auto-categorize",
        action="store_true",
        help="Auto-assign a category from description keywords",
    )

    # -- remove --------------------------------------------------------------
    p_rm = sub.add_parser("remove", aliases=["rm"], help="Remove a repository")
    p_rm.add_argument("name", help="Repository name to remove")

    # -- list ----------------------------------------------------------------
    p_list = sub.add_parser("list", aliases=["ls"], help="List repositories")
    p_list.add_argument("--category", "-c", help="Filter by category")
    p_list.add_argument("--tags", "-t", help="Filter by tags (comma-separated, AND logic)")
    p_list.add_argument("--search", "-s", help="Substring search in name/description")
    p_list.add_argument("--verbose", "-v", action="store_true", help="Show metadata too")

    # -- show ----------------------------------------------------------------
    p_show = sub.add_parser("show", help="Show details for a single repository")
    p_show.add_argument("name", help="Repository name")

    # -- update --------------------------------------------------------------
    p_update = sub.add_parser("update", help="Update repository fields")
    p_update.add_argument("name", help="Repository name")
    p_update.add_argument("--url", help="New URL")
    p_update.add_argument("--description", "-d", help="New description")
    p_update.add_argument("--category", "-c", help="New category key")
    p_update.add_argument("--tags", "-t", help="Replace tags (comma-separated)")
    p_update.add_argument("--metadata", "-m", help="Metadata JSON to merge in")

    # -- tag -----------------------------------------------------------------
    p_tag = sub.add_parser("tag", help="Add or remove tags on a repository")
    p_tag.add_argument("name", help="Repository name")
    p_tag.add_argument("--tags", "-t", required=True, help="Comma-separated tags")
    p_tag.add_argument("--remove", action="store_true", help="Remove these tags instead")

    # -- categorize ----------------------------------------------------------
    p_cat = sub.add_parser("categorize", help="Assign a category to a repository")
    p_cat.add_argument("name", help="Repository name")
    p_cat.add_argument("category", help="Category key")

    # -- categories ----------------------------------------------------------
    p_cats = sub.add_parser("categories", help="Manage categories")
    cat_sub = p_cats.add_subparsers(dest="cat_action", metavar="<action>")
    cat_sub.required = True

    cat_sub.add_parser("list", help="List all categories")

    p_cadd = cat_sub.add_parser("add", help="Add a custom category")
    p_cadd.add_argument("key", help="Category key (slug, e.g. 'ai-health')")
    p_cadd.add_argument("description", help="Category description")

    p_crm = cat_sub.add_parser("remove", help="Remove a custom category")
    p_crm.add_argument("key", help="Category key to remove")

    # -- fetch ---------------------------------------------------------------
    p_fetch = sub.add_parser(
        "fetch", help="Fetch repositories from GitHub and auto-categorize"
    )
    p_fetch.add_argument("username", help="GitHub username or organisation")
    p_fetch.add_argument("--token", help="GitHub personal access token (or set GITHUB_TOKEN)")
    p_fetch.add_argument(
        "--no-auto-categorize",
        action="store_true",
        help="Skip automatic category assignment",
    )

    # -- export --------------------------------------------------------------
    p_export = sub.add_parser("export", help="Export the catalogue to a file")
    p_export.add_argument("--output", "-o", required=True, help="Output file path")
    p_export.add_argument(
        "--format", "-f", choices=["json", "csv"], default="json", help="Output format"
    )

    # -- import --------------------------------------------------------------
    p_import = sub.add_parser("import", help="Import repositories from a JSON file")
    p_import.add_argument("input", help="Input JSON file path")
    p_import.add_argument(
        "--overwrite", action="store_true", help="Overwrite existing entries"
    )

    # -- cooldown ------------------------------------------------------------
    p_cooldown = sub.add_parser(
        "cooldown",
        help="Run a pre-task SoC cooldown sequence (iPad Pro M2)",
    )
    p_cooldown.add_argument(
        "--duration",
        "-n",
        type=int,
        default=30,
        metavar="SECONDS",
        help="Cooldown duration in seconds (default: 30)",
    )
    p_cooldown.add_argument(
        "--label",
        "-l",
        default="SoC Cooldown",
        help='Display label shown in the header (default: "SoC Cooldown")',
    )
    p_cooldown.add_argument(
        "--verbose",
        "-v",
        action="store_true",
        help="Print one line per second instead of an in-place countdown",
    )

    return parser


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

_COMMAND_MAP = {
    "add": _cmd_add,
    "remove": _cmd_remove,
    "rm": _cmd_remove,
    "list": _cmd_list,
    "ls": _cmd_list,
    "show": _cmd_show,
    "update": _cmd_update,
    "tag": _cmd_tag,
    "categorize": _cmd_categorize,
    "categories": _cmd_categories,
    "fetch": _cmd_fetch,
    "export": _cmd_export,
    "import": _cmd_import,
    "cooldown": _cmd_cooldown,
}


def main(argv: Optional[List[str]] = None) -> int:
    parser = _build_parser()
    args = parser.parse_args(argv)
    sorter = RepoSorter(db_path=args.db)
    handler = _COMMAND_MAP[args.command]
    return handler(args, sorter)


if __name__ == "__main__":  # pragma: no cover
    sys.exit(main())
