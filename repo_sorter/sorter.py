"""
Core data model and CRUD operations for the medical repository sorter.

How it works
------------
1. All repository data is kept in a single JSON file on disk
   (default: ``~/.repo_sorter/repos.json``).
2. Every public method loads the file, makes its change, and saves the
   file back — keeping the on-disk state always consistent.
3. Categories come from two places: the built-in ``data/categories.json``
   bundled with the package, and an optional
   ``~/.repo_sorter/custom_categories.json`` for user-defined ones.

Repository record schema
------------------------
Each entry in the database has the following fields::

    {
        "name":        str,          # unique identifier, e.g. "owner/repo"
        "url":         str | None,   # GitHub URL
        "description": str | None,   # short description
        "category":    str | None,   # one of the keys in categories.json
        "tags":        list[str],    # free-form tags (always sorted)
        "metadata":    dict          # arbitrary extra key/value pairs
    }
"""

import json
import os
from copy import deepcopy
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

_DEFAULT_DB_PATH = Path.home() / ".repo_sorter" / "repos.json"
_BUILTIN_CATEGORIES_PATH = Path(__file__).parent / "data" / "categories.json"


# ---------------------------------------------------------------------------
# Categories helpers
# ---------------------------------------------------------------------------

def load_builtin_categories() -> Dict[str, str]:
    """Return the built-in medical category definitions from the bundled JSON file."""
    with open(_BUILTIN_CATEGORIES_PATH, encoding="utf-8") as fh:
        return json.load(fh)["categories"]


def load_categories(db_path: Optional[Path] = None) -> Dict[str, str]:
    """
    Return all available categories: built-in defaults merged with any
    user-defined custom categories stored next to the repository database.

    Custom categories take precedence — if a custom entry has the same key
    as a built-in one, the custom description wins.
    """
    # Start with the bundled medical categories shipped with the package
    categories = load_builtin_categories()

    # Look for custom categories saved in the same directory as the database
    db_path = Path(db_path) if db_path else _DEFAULT_DB_PATH
    custom_path = db_path.parent / "custom_categories.json"
    if custom_path.exists():
        with open(custom_path, encoding="utf-8") as fh:
            custom = json.load(fh).get("categories", {})
        # Merge: custom entries override built-in entries with the same key
        categories.update(custom)
    return categories


def save_custom_category(
    key: str,
    description: str,
    db_path: Optional[Path] = None,
) -> None:
    """
    Persist a new or updated custom category to the custom_categories.json
    file that lives next to the main database.

    If the file does not yet exist it is created automatically.
    """
    db_path = Path(db_path) if db_path else _DEFAULT_DB_PATH
    custom_path = db_path.parent / "custom_categories.json"

    # Read the current custom categories (or start with an empty structure)
    existing: Dict[str, Any] = {"categories": {}}
    if custom_path.exists():
        with open(custom_path, encoding="utf-8") as fh:
            existing = json.load(fh)

    # Add / overwrite the entry
    existing.setdefault("categories", {})[key] = description

    # Make sure the directory exists, then write back
    custom_path.parent.mkdir(parents=True, exist_ok=True)
    with open(custom_path, "w", encoding="utf-8") as fh:
        json.dump(existing, fh, indent=2)


def remove_custom_category(key: str, db_path: Optional[Path] = None) -> bool:
    """
    Remove a custom category from the custom_categories.json file.

    Returns True if the key was found and deleted, False if it was not present.
    """
    db_path = Path(db_path) if db_path else _DEFAULT_DB_PATH
    custom_path = db_path.parent / "custom_categories.json"

    # Nothing to remove if the file doesn't exist
    if not custom_path.exists():
        return False

    with open(custom_path, encoding="utf-8") as fh:
        data = json.load(fh)

    cats = data.get("categories", {})
    if key not in cats:
        return False  # key was not present

    del cats[key]

    with open(custom_path, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2)
    return True


# ---------------------------------------------------------------------------
# Database helpers
# ---------------------------------------------------------------------------

def _load_db(db_path: Path) -> Dict[str, Any]:
    """
    Load the JSON database from disk.

    If the file does not exist yet (first run), return an empty catalogue
    structure so the rest of the code never has to handle a missing key.
    """
    if db_path.exists():
        with open(db_path, encoding="utf-8") as fh:
            return json.load(fh)
    # First-run default: empty catalogue
    return {"repositories": {}}


def _save_db(db_path: Path, data: Dict[str, Any]) -> None:
    """Write the database to disk, creating any missing parent directories."""
    db_path.parent.mkdir(parents=True, exist_ok=True)
    with open(db_path, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2)


def _make_entry(
    name: str,
    url: Optional[str] = None,
    description: Optional[str] = None,
    category: Optional[str] = None,
    tags: Optional[List[str]] = None,
    metadata: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    """
    Build a fresh repository record dict with all required fields.

    Tags are deduplicated and sorted so the stored list is always
    deterministic regardless of the order the caller provides them.
    """
    return {
        "name": name,
        "url": url,
        "description": description,
        "category": category,
        "tags": sorted(set(tags or [])),   # deduplicate + sort
        "metadata": metadata or {},
    }


# ---------------------------------------------------------------------------
# Public CRUD API
# ---------------------------------------------------------------------------

class RepoSorter:
    """High-level interface for managing a local medical repo catalogue."""

    def __init__(self, db_path: Optional[str] = None):
        self.db_path: Path = Path(db_path) if db_path else _DEFAULT_DB_PATH

    # -- helpers -------------------------------------------------------------

    def _load(self) -> Dict[str, Any]:
        return _load_db(self.db_path)

    def _save(self, data: Dict[str, Any]) -> None:
        _save_db(self.db_path, data)

    def _repos(self, data: Dict[str, Any]) -> Dict[str, Any]:
        return data.setdefault("repositories", {})

    # -- repositories --------------------------------------------------------

    def add(
        self,
        name: str,
        url: Optional[str] = None,
        description: Optional[str] = None,
        category: Optional[str] = None,
        tags: Optional[List[str]] = None,
        metadata: Optional[Dict[str, Any]] = None,
        overwrite: bool = False,
    ) -> Dict[str, Any]:
        """
        Add a repository to the catalogue.

        Parameters
        ----------
        name:        Unique name/identifier (e.g. ``"owner/my-ehr-system"``).
        url:         Optional GitHub URL.
        description: Optional human-readable description.
        category:    Optional category key (see ``list_categories``).
        tags:        Optional list of free-form tags.
        metadata:    Optional arbitrary metadata dictionary.
        overwrite:   If True, replace an existing entry with the same name.
        """
        data = self._load()
        repos = self._repos(data)
        if name in repos and not overwrite:
            raise ValueError(
                f"Repository '{name}' already exists. "
                "Use overwrite=True or the 'update' command to modify it."
            )
        entry = _make_entry(name, url, description, category, tags, metadata)
        repos[name] = entry
        self._save(data)
        return deepcopy(entry)

    def remove(self, name: str) -> bool:
        """Remove a repository; returns True if it existed."""
        data = self._load()
        repos = self._repos(data)
        if name not in repos:
            return False
        del repos[name]
        self._save(data)
        return True

    def get(self, name: str) -> Optional[Dict[str, Any]]:
        """Return a single repository entry or None."""
        repos = self._repos(self._load())
        return deepcopy(repos.get(name))

    def update(self, name: str, **fields: Any) -> Dict[str, Any]:
        """
        Update one or more fields of an existing repository.

        Recognised fields: ``url``, ``description``, ``category``,
        ``tags`` (replaces), ``metadata`` (merges).
        """
        data = self._load()
        repos = self._repos(data)
        if name not in repos:
            raise KeyError(f"Repository '{name}' not found.")
        entry = repos[name]
        if "url" in fields:
            entry["url"] = fields["url"]
        if "description" in fields:
            entry["description"] = fields["description"]
        if "category" in fields:
            entry["category"] = fields["category"]
        if "tags" in fields:
            entry["tags"] = sorted(set(fields["tags"]))
        if "metadata" in fields:
            entry["metadata"].update(fields["metadata"])
        self._save(data)
        return deepcopy(entry)

    def add_tags(self, name: str, tags: List[str]) -> Dict[str, Any]:
        """Append tags to a repository (duplicates are ignored)."""
        data = self._load()
        repos = self._repos(data)
        if name not in repos:
            raise KeyError(f"Repository '{name}' not found.")
        existing = set(repos[name]["tags"])
        repos[name]["tags"] = sorted(existing | set(tags))
        self._save(data)
        return deepcopy(repos[name])

    def remove_tags(self, name: str, tags: List[str]) -> Dict[str, Any]:
        """Remove specific tags from a repository."""
        data = self._load()
        repos = self._repos(data)
        if name not in repos:
            raise KeyError(f"Repository '{name}' not found.")
        existing = set(repos[name]["tags"])
        repos[name]["tags"] = sorted(existing - set(tags))
        self._save(data)
        return deepcopy(repos[name])

    # -- listing / filtering -------------------------------------------------

    def list_all(self) -> List[Dict[str, Any]]:
        """Return all repository entries."""
        repos = self._repos(self._load())
        return [deepcopy(r) for r in repos.values()]

    def filter(
        self,
        category: Optional[str] = None,
        tags: Optional[List[str]] = None,
        search: Optional[str] = None,
    ) -> List[Dict[str, Any]]:
        """
        Return repositories matching the given criteria.

        All criteria are AND-combined, meaning a repository must satisfy
        *every* non-None criterion to appear in the results.

        Parameters
        ----------
        category: Match the ``category`` field exactly (case-sensitive).
        tags:     Repository must have **all** of these tags (AND logic).
        search:   Case-insensitive substring match against name and
                  description.
        """
        # Begin with the full catalogue, then narrow down step by step
        results = self.list_all()

        # Step 1 — keep only repositories in the requested category
        if category:
            results = [r for r in results if r.get("category") == category]

        # Step 2 — keep only repositories that have ALL the requested tags
        if tags:
            tag_set = set(tags)
            results = [r for r in results if tag_set.issubset(set(r["tags"]))]

        # Step 3 — keep only repositories whose name or description contains
        #           the search term (case-insensitive substring match)
        if search:
            term = search.lower()
            results = [
                r for r in results
                if term in (r.get("name") or "").lower()
                or term in (r.get("description") or "").lower()
            ]

        return results

    # -- categories ----------------------------------------------------------

    def list_categories(self) -> Dict[str, str]:
        """Return all categories (built-in + custom)."""
        return load_categories(self.db_path)

    def add_category(self, key: str, description: str) -> None:
        """Add or update a custom category."""
        save_custom_category(key, description, self.db_path)

    def remove_category(self, key: str) -> bool:
        """Remove a custom category; returns True if it existed."""
        return remove_custom_category(key, self.db_path)

    # -- import / export -----------------------------------------------------

    def export(self, output_path: str, fmt: str = "json") -> None:
        """
        Export the full catalogue to a file.

        Parameters
        ----------
        output_path: File path to write to.
        fmt:         ``"json"`` (default) or ``"csv"``.

        JSON output preserves the full schema and can be round-tripped back
        with :meth:`import_repos`.  CSV output is human-readable in a
        spreadsheet but flattens ``tags`` to a comma-joined string and
        ``metadata`` to a JSON string.
        """
        repos = self.list_all()
        output_path = Path(output_path)

        if fmt == "json":
            # Wrap the list in a top-level "repositories" key so the file
            # format matches the internal database structure
            with open(output_path, "w", encoding="utf-8") as fh:
                json.dump({"repositories": repos}, fh, indent=2)

        elif fmt == "csv":
            import csv
            fieldnames = ["name", "url", "description", "category", "tags", "metadata"]
            with open(output_path, "w", newline="", encoding="utf-8") as fh:
                writer = csv.DictWriter(fh, fieldnames=fieldnames)
                writer.writeheader()
                for repo in repos:
                    row = dict(repo)
                    # Flatten list → comma-separated string for CSV cells
                    row["tags"] = ",".join(repo.get("tags") or [])
                    # Flatten dict → JSON string for CSV cells
                    row["metadata"] = json.dumps(repo.get("metadata") or {})
                    writer.writerow(row)

        else:
            raise ValueError(f"Unsupported export format: {fmt!r}")

    def import_repos(self, input_path: str, overwrite: bool = False) -> int:
        """
        Import repositories from a JSON file previously created by
        :meth:`export`.

        The file may contain repositories as either a list or a dict (both
        formats are accepted for convenience).  Returns the number of
        repositories successfully imported.
        """
        # Load the exported file
        with open(input_path, encoding="utf-8") as fh:
            data = json.load(fh)

        repos = data.get("repositories", [])

        # Support both list format (from JSON export) and dict format
        # (direct copy of the internal database structure)
        if isinstance(repos, dict):
            repos = list(repos.values())

        # Add each repository to the catalogue one by one
        count = 0
        for repo in repos:
            self.add(
                name=repo["name"],
                url=repo.get("url"),
                description=repo.get("description"),
                category=repo.get("category"),
                tags=repo.get("tags"),
                metadata=repo.get("metadata"),
                overwrite=overwrite,
            )
            count += 1
        return count

    def fetch_from_github(
        self,
        username: str,
        token: Optional[str] = None,
        auto_categorize: bool = True,
    ) -> List[Dict[str, Any]]:
        """
        Fetch public (and, with a token, private) repositories from GitHub
        and add them to the catalogue.

        The GitHub API returns up to 100 repositories per page, so this
        method automatically follows pagination until there are no more
        results.

        Parameters
        ----------
        username:        GitHub username or organisation name.
        token:           Personal access token for private repos / higher
                         rate limits.  Falls back to the ``GITHUB_TOKEN``
                         environment variable when not supplied directly.
        auto_categorize: When True, attempt to assign a medical category
                         automatically based on the repository's description
                         text and topic tags.

        Returns a list of the newly added / updated catalogue entries.
        """
        import urllib.request
        import urllib.error

        # Prefer the explicitly supplied token; fall back to the environment
        resolved_token = token or os.environ.get("GITHUB_TOKEN")

        # Build request headers; authentication is optional but recommended
        # to get a higher API rate limit (5 000 req/h vs 60 req/h unauthenticated)
        headers = {"Accept": "application/vnd.github+json"}
        if resolved_token:
            headers["Authorization"] = f"Bearer {resolved_token}"

        # Paginate through all repositories (100 per page)
        page, all_repos = 1, []
        while True:
            url = (
                f"https://api.github.com/users/{username}/repos"
                f"?per_page=100&page={page}&type=all"
            )
            req = urllib.request.Request(url, headers=headers)
            try:
                with urllib.request.urlopen(req) as resp:
                    batch = json.loads(resp.read().decode())
            except urllib.error.HTTPError as exc:
                raise RuntimeError(
                    f"GitHub API error {exc.code}: {exc.reason}"
                ) from exc

            # An empty page means we have fetched everything
            if not batch:
                break

            all_repos.extend(batch)
            page += 1

        # Convert each GitHub API repository object into a catalogue entry
        added = []
        for gh_repo in all_repos:
            name = gh_repo["full_name"]  # e.g. "octocat/Hello-World"

            # Optionally guess the medical category from description + topics
            category = None
            if auto_categorize:
                category = _auto_categorize(
                    gh_repo.get("description") or "",
                    gh_repo.get("topics") or [],
                )

            # Add (or refresh) the entry; overwrite=True keeps the catalogue
            # in sync when the command is run repeatedly
            entry = self.add(
                name=name,
                url=gh_repo["html_url"],
                description=gh_repo.get("description"),
                category=category,
                tags=gh_repo.get("topics") or [],
                metadata={
                    "stars": gh_repo.get("stargazers_count", 0),
                    "language": gh_repo.get("language"),
                    "private": gh_repo.get("private", False),
                },
                overwrite=True,
            )
            added.append(entry)
        return added


# ---------------------------------------------------------------------------
# Auto-categorisation heuristic
# ---------------------------------------------------------------------------

# Each entry is a (category_key, keywords) pair.
# The list is ordered from most specific to most general so that, for example,
# "medical imaging" is matched before the catch-all "general-healthcare".
# The first category whose keyword list contains a match is returned.
_KEYWORD_MAP: List[Tuple[str, List[str]]] = [
    ("medical-imaging", ["dicom", "radiology", "mri", "ct scan", "x-ray", "pathology", "imaging"]),
    ("ehr", ["ehr", "emr", "fhir", "hl7", "electronic health", "health record", "clinical data"]),
    ("telemedicine", ["telemedicine", "telehealth", "video consult", "remote care", "virtual visit"]),
    ("pharmacology", ["pharmacy", "drug", "medication", "dosage", "prescription", "pharmacology"]),
    ("diagnostics", ["diagnostic", "lab result", "test result", "clinical decision", "diagnosis"]),
    ("research", ["research", "clinical trial", "biostatistics", "epidemiology", "cohort study"]),
    ("patient-management", ["patient", "appointment", "scheduling", "intake", "care coordination"]),
    ("wearables", ["wearable", "iot health", "sensor", "heart rate", "fitness tracker"]),
    ("mental-health", ["mental health", "mood", "depression", "anxiety", "psychiatry", "psychotherapy"]),
    ("emergency", ["emergency", "triage", "ems", "ambulance", "critical care", "trauma"]),
    ("genomics", ["genomics", "bioinformatics", "dna", "genome", "sequencing", "precision medicine"]),
    ("nutrition", ["nutrition", "diet", "calorie", "dietary", "food", "wellness"]),
    ("rehabilitation", ["rehabilitation", "physical therapy", "occupational therapy", "rehab"]),
    ("general-healthcare", ["health", "medical", "hospital", "clinic", "care"]),
]


def _auto_categorize(description: str, topics: List[str]) -> Optional[str]:
    """
    Return the best-matching medical category key, or None if no keyword
    matches.

    How it works
    ------------
    1. Combine the description and GitHub topic tags into a single lowercase
       string so both sources are checked in one pass.
    2. Walk through ``_KEYWORD_MAP`` in order (most specific first).
    3. Return the first category whose keyword list has any match.
    """
    # Join description + topics into one searchable text blob
    text = " ".join([description] + topics).lower()

    for category, keywords in _KEYWORD_MAP:
        if any(kw in text for kw in keywords):
            return category  # first match wins

    # No keyword matched → category unknown
    return None
