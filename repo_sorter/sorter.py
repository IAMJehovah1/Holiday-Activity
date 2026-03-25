"""
Core data model and CRUD operations for the medical repository sorter.

Repository records are persisted in a local JSON database file
(default: ~/.repo_sorter/repos.json).  The schema for each repository
entry is::

    {
        "name":        str,          # unique identifier, e.g. "owner/repo"
        "url":         str | None,   # GitHub URL
        "description": str | None,   # short description
        "category":    str | None,   # one of the keys in categories.json
        "tags":        list[str],    # free-form tags
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
    """Return the built-in medical category definitions."""
    with open(_BUILTIN_CATEGORIES_PATH, encoding="utf-8") as fh:
        return json.load(fh)["categories"]


def load_categories(db_path: Optional[Path] = None) -> Dict[str, str]:
    """
    Return merged categories: built-in defaults overridden/extended by any
    custom categories stored alongside the repository database.
    """
    categories = load_builtin_categories()
    db_path = Path(db_path) if db_path else _DEFAULT_DB_PATH
    custom_path = db_path.parent / "custom_categories.json"
    if custom_path.exists():
        with open(custom_path, encoding="utf-8") as fh:
            custom = json.load(fh).get("categories", {})
        categories.update(custom)
    return categories


def save_custom_category(
    key: str,
    description: str,
    db_path: Optional[Path] = None,
) -> None:
    """Persist a new or updated custom category."""
    db_path = Path(db_path) if db_path else _DEFAULT_DB_PATH
    custom_path = db_path.parent / "custom_categories.json"
    existing: Dict[str, Any] = {"categories": {}}
    if custom_path.exists():
        with open(custom_path, encoding="utf-8") as fh:
            existing = json.load(fh)
    existing.setdefault("categories", {})[key] = description
    custom_path.parent.mkdir(parents=True, exist_ok=True)
    with open(custom_path, "w", encoding="utf-8") as fh:
        json.dump(existing, fh, indent=2)


def remove_custom_category(key: str, db_path: Optional[Path] = None) -> bool:
    """Remove a custom category; returns True if the key existed."""
    db_path = Path(db_path) if db_path else _DEFAULT_DB_PATH
    custom_path = db_path.parent / "custom_categories.json"
    if not custom_path.exists():
        return False
    with open(custom_path, encoding="utf-8") as fh:
        data = json.load(fh)
    cats = data.get("categories", {})
    if key not in cats:
        return False
    del cats[key]
    with open(custom_path, "w", encoding="utf-8") as fh:
        json.dump(data, fh, indent=2)
    return True


# ---------------------------------------------------------------------------
# Database helpers
# ---------------------------------------------------------------------------

def _load_db(db_path: Path) -> Dict[str, Any]:
    """Load raw JSON database; create empty structure if file is absent."""
    if db_path.exists():
        with open(db_path, encoding="utf-8") as fh:
            return json.load(fh)
    return {"repositories": {}}


def _save_db(db_path: Path, data: Dict[str, Any]) -> None:
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
    return {
        "name": name,
        "url": url,
        "description": description,
        "category": category,
        "tags": sorted(set(tags or [])),
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
        Return repositories matching the given criteria (all criteria are
        AND-combined).

        Parameters
        ----------
        category: Match the ``category`` field exactly.
        tags:     Repository must have **all** of these tags.
        search:   Case-insensitive substring match against name and
                  description.
        """
        results = self.list_all()
        if category:
            results = [r for r in results if r.get("category") == category]
        if tags:
            tag_set = set(tags)
            results = [r for r in results if tag_set.issubset(set(r["tags"]))]
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
        Export the full catalogue.

        Parameters
        ----------
        output_path: File path to write to.
        fmt:         ``"json"`` (default) or ``"csv"``.
        """
        repos = self.list_all()
        output_path = Path(output_path)
        if fmt == "json":
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
                    row["tags"] = ",".join(repo.get("tags") or [])
                    row["metadata"] = json.dumps(repo.get("metadata") or {})
                    writer.writerow(row)
        else:
            raise ValueError(f"Unsupported export format: {fmt!r}")

    def import_repos(self, input_path: str, overwrite: bool = False) -> int:
        """
        Import repositories from a JSON file previously created by
        :meth:`export`.  Returns the number of repositories imported.
        """
        with open(input_path, encoding="utf-8") as fh:
            data = json.load(fh)
        repos = data.get("repositories", [])
        # Support both list and dict formats
        if isinstance(repos, dict):
            repos = list(repos.values())
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

        Parameters
        ----------
        username:        GitHub username or organisation name.
        token:           Personal access token for private repos / higher
                         rate limits.  If not supplied the GITHUB_TOKEN
                         environment variable is used when present.
        auto_categorize: Attempt to auto-assign a medical category based on
                         repository topics and description keywords.

        Returns a list of the newly added / updated entries.
        """
        import urllib.request
        import urllib.error

        resolved_token = token or os.environ.get("GITHUB_TOKEN")
        headers = {"Accept": "application/vnd.github+json"}
        if resolved_token:
            headers["Authorization"] = f"Bearer {resolved_token}"

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
            if not batch:
                break
            all_repos.extend(batch)
            page += 1

        added = []
        for gh_repo in all_repos:
            name = gh_repo["full_name"]
            category = None
            if auto_categorize:
                category = _auto_categorize(
                    gh_repo.get("description") or "",
                    gh_repo.get("topics") or [],
                )
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
    """Return the best-matching medical category key or None."""
    text = " ".join([description] + topics).lower()
    for category, keywords in _KEYWORD_MAP:
        if any(kw in text for kw in keywords):
            return category
    return None
