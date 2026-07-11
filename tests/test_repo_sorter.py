"""
Tests for repo_sorter.sorter (core logic) and repo_sorter.cli (command-line interface).
"""

import json
import os
import sys
import tempfile
from pathlib import Path

import pytest

# Make sure the package is importable when running from the repo root
sys.path.insert(0, str(Path(__file__).parent.parent))

from repo_sorter.sorter import RepoSorter, _auto_categorize, load_builtin_categories


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture()
def db_path(tmp_path):
    """Return a temporary database file path."""
    return str(tmp_path / "repos.json")


@pytest.fixture()
def sorter(db_path):
    return RepoSorter(db_path=db_path)


# ---------------------------------------------------------------------------
# Built-in categories
# ---------------------------------------------------------------------------


class TestBuiltinCategories:
    def test_builtin_categories_loaded(self):
        cats = load_builtin_categories()
        assert isinstance(cats, dict)
        assert len(cats) >= 10

    def test_known_categories_present(self):
        cats = load_builtin_categories()
        for expected in ("ehr", "diagnostics", "telemedicine", "pharmacology"):
            assert expected in cats, f"Missing category: {expected}"


# ---------------------------------------------------------------------------
# RepoSorter – CRUD
# ---------------------------------------------------------------------------


class TestAdd:
    def test_add_minimal(self, sorter):
        entry = sorter.add("owner/repo")
        assert entry["name"] == "owner/repo"
        assert entry["category"] is None
        assert entry["tags"] == []

    def test_add_with_all_fields(self, sorter):
        entry = sorter.add(
            "owner/ehr",
            url="https://github.com/owner/ehr",
            description="EHR system",
            category="ehr",
            tags=["fhir", "hl7"],
            metadata={"stars": 10},
        )
        assert entry["category"] == "ehr"
        assert "fhir" in entry["tags"]
        assert entry["metadata"]["stars"] == 10

    def test_add_duplicate_raises(self, sorter):
        sorter.add("owner/repo")
        with pytest.raises(ValueError, match="already exists"):
            sorter.add("owner/repo")

    def test_add_duplicate_overwrite(self, sorter):
        sorter.add("owner/repo", description="v1")
        entry = sorter.add("owner/repo", description="v2", overwrite=True)
        assert entry["description"] == "v2"

    def test_tags_deduplicated(self, sorter):
        entry = sorter.add("owner/repo", tags=["fhir", "fhir", "hl7"])
        assert entry["tags"] == ["fhir", "hl7"]


class TestRemove:
    def test_remove_existing(self, sorter):
        sorter.add("owner/repo")
        assert sorter.remove("owner/repo") is True
        assert sorter.get("owner/repo") is None

    def test_remove_nonexistent(self, sorter):
        assert sorter.remove("nobody/nowhere") is False


class TestGet:
    def test_get_existing(self, sorter):
        sorter.add("owner/repo", description="hello")
        entry = sorter.get("owner/repo")
        assert entry["description"] == "hello"

    def test_get_nonexistent(self, sorter):
        assert sorter.get("nobody/nowhere") is None


class TestUpdate:
    def test_update_fields(self, sorter):
        sorter.add("owner/repo", description="old")
        entry = sorter.update("owner/repo", description="new", category="ehr")
        assert entry["description"] == "new"
        assert entry["category"] == "ehr"

    def test_update_nonexistent_raises(self, sorter):
        with pytest.raises(KeyError):
            sorter.update("nobody/nowhere", description="x")

    def test_update_tags_replaces(self, sorter):
        sorter.add("owner/repo", tags=["a", "b"])
        entry = sorter.update("owner/repo", tags=["c"])
        assert entry["tags"] == ["c"]

    def test_update_metadata_merges(self, sorter):
        sorter.add("owner/repo", metadata={"a": 1})
        entry = sorter.update("owner/repo", metadata={"b": 2})
        assert entry["metadata"] == {"a": 1, "b": 2}


class TestTags:
    def test_add_tags(self, sorter):
        sorter.add("owner/repo", tags=["a"])
        entry = sorter.add_tags("owner/repo", ["b", "c"])
        assert "b" in entry["tags"]
        assert "c" in entry["tags"]

    def test_add_tags_no_duplicates(self, sorter):
        sorter.add("owner/repo", tags=["a"])
        entry = sorter.add_tags("owner/repo", ["a", "b"])
        assert entry["tags"].count("a") == 1

    def test_remove_tags(self, sorter):
        sorter.add("owner/repo", tags=["a", "b", "c"])
        entry = sorter.remove_tags("owner/repo", ["a", "c"])
        assert entry["tags"] == ["b"]

    def test_add_tags_nonexistent_raises(self, sorter):
        with pytest.raises(KeyError):
            sorter.add_tags("nobody/nowhere", ["x"])

    def test_remove_tags_nonexistent_raises(self, sorter):
        with pytest.raises(KeyError):
            sorter.remove_tags("nobody/nowhere", ["x"])


# ---------------------------------------------------------------------------
# RepoSorter – filtering
# ---------------------------------------------------------------------------


class TestFilter:
    @pytest.fixture(autouse=True)
    def _populate(self, sorter):
        sorter.add("org/ehr-system", category="ehr", tags=["fhir"], description="EHR")
        sorter.add("org/dicom-viewer", category="medical-imaging", tags=["dicom"])
        sorter.add("org/telehealth", category="telemedicine", tags=["fhir", "video"])
        sorter.add("org/random", category="other")

    def test_filter_by_category(self, sorter):
        results = sorter.filter(category="ehr")
        assert len(results) == 1
        assert results[0]["name"] == "org/ehr-system"

    def test_filter_by_tag(self, sorter):
        results = sorter.filter(tags=["fhir"])
        names = {r["name"] for r in results}
        assert "org/ehr-system" in names
        assert "org/telehealth" in names

    def test_filter_by_multiple_tags(self, sorter):
        results = sorter.filter(tags=["fhir", "video"])
        assert len(results) == 1
        assert results[0]["name"] == "org/telehealth"

    def test_filter_by_search(self, sorter):
        results = sorter.filter(search="ehr")
        assert any(r["name"] == "org/ehr-system" for r in results)

    def test_filter_combined(self, sorter):
        results = sorter.filter(category="telemedicine", tags=["fhir"])
        assert len(results) == 1

    def test_list_all(self, sorter):
        assert len(sorter.list_all()) == 4


# ---------------------------------------------------------------------------
# RepoSorter – custom categories
# ---------------------------------------------------------------------------


class TestCustomCategories:
    def test_add_and_list_custom_category(self, sorter):
        sorter.add_category("ai-health", "AI tools for healthcare")
        cats = sorter.list_categories()
        assert "ai-health" in cats
        assert cats["ai-health"] == "AI tools for healthcare"

    def test_remove_custom_category(self, sorter):
        sorter.add_category("ai-health", "AI tools for healthcare")
        assert sorter.remove_category("ai-health") is True
        cats = sorter.list_categories()
        assert "ai-health" not in cats

    def test_remove_nonexistent_custom_category(self, sorter):
        assert sorter.remove_category("nonexistent-cat") is False

    def test_builtin_categories_unchanged_after_custom_add(self, sorter):
        sorter.add_category("custom-cat", "Custom")
        cats = sorter.list_categories()
        # Built-in categories should still be present
        assert "ehr" in cats
        assert "diagnostics" in cats


# ---------------------------------------------------------------------------
# RepoSorter – export / import
# ---------------------------------------------------------------------------


class TestExportImport:
    def test_export_json(self, sorter, tmp_path):
        sorter.add("owner/repo", category="ehr")
        out = str(tmp_path / "export.json")
        sorter.export(out, fmt="json")
        with open(out) as fh:
            data = json.load(fh)
        assert len(data["repositories"]) == 1

    def test_export_csv(self, sorter, tmp_path):
        sorter.add("owner/repo", tags=["fhir"])
        out = str(tmp_path / "export.csv")
        sorter.export(out, fmt="csv")
        content = Path(out).read_text()
        assert "owner/repo" in content
        assert "fhir" in content

    def test_export_invalid_format(self, sorter, tmp_path):
        sorter.add("owner/repo")
        with pytest.raises(ValueError):
            sorter.export(str(tmp_path / "out.txt"), fmt="xml")

    def test_import_json(self, sorter, tmp_path):
        sorter.add("owner/repo-a", category="ehr")
        sorter.add("owner/repo-b", category="diagnostics")
        out = str(tmp_path / "export.json")
        sorter.export(out, fmt="json")

        sorter2 = RepoSorter(db_path=str(tmp_path / "repos2.json"))
        count = sorter2.import_repos(out)
        assert count == 2
        assert sorter2.get("owner/repo-a")["category"] == "ehr"

    def test_import_overwrite(self, sorter, tmp_path):
        sorter.add("owner/repo", description="original")
        out = str(tmp_path / "export.json")
        sorter.export(out, fmt="json")

        sorter.update("owner/repo", description="updated")
        out2 = str(tmp_path / "export2.json")
        sorter.export(out2, fmt="json")

        sorter2 = RepoSorter(db_path=str(tmp_path / "repos2.json"))
        sorter2.import_repos(out)
        sorter2.import_repos(out2, overwrite=True)
        assert sorter2.get("owner/repo")["description"] == "updated"


# ---------------------------------------------------------------------------
# Auto-categorise heuristic
# ---------------------------------------------------------------------------


class TestAutoCategorize:
    @pytest.mark.parametrize("text,expected", [
        ("Electronic Health Record system", "ehr"),
        ("DICOM viewer for radiology", "medical-imaging"),
        ("Remote telemedicine platform", "telemedicine"),
        ("Drug dosage calculator", "pharmacology"),
        ("clinical trial management", "research"),
        ("patient appointment scheduling", "patient-management"),
        ("heart rate wearable sensor", "wearables"),
        ("mental health therapy app", "mental-health"),
        ("emergency triage system", "emergency"),
        ("genome sequencing tool", "genomics"),
        ("calorie nutrition tracker", "nutrition"),
        ("physical therapy rehabilitation", "rehabilitation"),
        ("general hospital management", "general-healthcare"),
        ("totally unrelated project", None),
    ])
    def test_auto_categorize(self, text, expected):
        result = _auto_categorize(text, [])
        assert result == expected

    def test_auto_categorize_uses_topics(self):
        result = _auto_categorize("", ["dicom", "radiology"])
        assert result == "medical-imaging"


# ---------------------------------------------------------------------------
# CLI – integration tests
# ---------------------------------------------------------------------------


class TestCLI:
    """Test the CLI end-to-end via main()."""

    from repo_sorter.cli import main as _main

    def _run(self, args, db_path, capsys):
        from repo_sorter.cli import main
        rc = main(["--db", db_path] + args)
        out, err = capsys.readouterr()
        return rc, out, err

    def test_add_and_list(self, db_path, capsys):
        rc, out, _ = self._run(
            ["add", "org/ehr", "--category", "ehr", "--tags", "fhir"],
            db_path,
            capsys,
        )
        assert rc == 0
        rc2, out2, _ = self._run(["list", "--category", "ehr"], db_path, capsys)
        assert rc2 == 0
        assert "org/ehr" in out2

    def test_remove(self, db_path, capsys):
        self._run(["add", "org/repo"], db_path, capsys)
        rc, _, _ = self._run(["remove", "org/repo"], db_path, capsys)
        assert rc == 0
        rc2, out, _ = self._run(["list"], db_path, capsys)
        assert "org/repo" not in out

    def test_show(self, db_path, capsys):
        self._run(
            ["add", "org/ehr", "--description", "My EHR", "--category", "ehr"],
            db_path,
            capsys,
        )
        rc, out, _ = self._run(["show", "org/ehr"], db_path, capsys)
        assert rc == 0
        assert "org/ehr" in out

    def test_tag_add_remove(self, db_path, capsys):
        self._run(["add", "org/repo"], db_path, capsys)
        rc, _, _ = self._run(["tag", "org/repo", "--tags", "fhir,hl7"], db_path, capsys)
        assert rc == 0
        rc2, _, _ = self._run(["tag", "org/repo", "--tags", "hl7", "--remove"], db_path, capsys)
        assert rc2 == 0
        rc3, out, _ = self._run(["show", "org/repo"], db_path, capsys)
        assert "hl7" not in out
        assert "fhir" in out

    def test_categorize(self, db_path, capsys):
        self._run(["add", "org/repo"], db_path, capsys)
        rc, out, _ = self._run(["categorize", "org/repo", "ehr"], db_path, capsys)
        assert rc == 0
        assert "ehr" in out

    def test_categories_list(self, db_path, capsys):
        rc, out, _ = self._run(["categories", "list"], db_path, capsys)
        assert rc == 0
        assert "ehr" in out
        assert "diagnostics" in out

    def test_categories_add_remove(self, db_path, capsys):
        rc, _, _ = self._run(
            ["categories", "add", "ai-health", "AI for healthcare"],
            db_path,
            capsys,
        )
        assert rc == 0
        rc2, out, _ = self._run(["categories", "list"], db_path, capsys)
        assert "ai-health" in out
        rc3, _, _ = self._run(["categories", "remove", "ai-health"], db_path, capsys)
        assert rc3 == 0

    def test_update(self, db_path, capsys):
        self._run(["add", "org/repo", "--description", "old"], db_path, capsys)
        rc, _, _ = self._run(
            ["update", "org/repo", "--description", "new", "--category", "ehr"],
            db_path,
            capsys,
        )
        assert rc == 0
        _, out, _ = self._run(["show", "org/repo"], db_path, capsys)
        assert "new" in out
        assert "ehr" in out

    def test_export_import(self, db_path, capsys, tmp_path):
        self._run(["add", "org/ehr", "--category", "ehr"], db_path, capsys)
        export_file = str(tmp_path / "export.json")
        rc, _, _ = self._run(["export", "--output", export_file], db_path, capsys)
        assert rc == 0

        db2 = str(tmp_path / "repos2.json")
        rc2, out, _ = self._run(["import", export_file], db2, capsys)
        assert rc2 == 0
        assert "Imported 1" in out

    def test_list_empty(self, db_path, capsys):
        rc, out, _ = self._run(["list"], db_path, capsys)
        assert rc == 0
        assert "No repositories found" in out

    def test_remove_nonexistent_returns_error(self, db_path, capsys):
        rc, _, _ = self._run(["remove", "nobody/nowhere"], db_path, capsys)
        assert rc == 1


# ---------------------------------------------------------------------------
# Cooldown – unit tests
# ---------------------------------------------------------------------------


class TestCooldown:
    """Tests for repo_sorter.cooldown.run_cooldown."""

    from repo_sorter.cooldown import run_cooldown as _run_cooldown

    def _cooldown(self, **kwargs):
        """Run cooldown with instant ticks and capture output."""
        import io
        from repo_sorter.cooldown import run_cooldown

        buf = io.StringIO()
        run_cooldown(_stream=buf, _tick=0, **kwargs)
        return buf.getvalue()

    def test_zero_duration_prints_ready(self):
        out = self._cooldown(duration=0)
        assert "Ready" in out

    def test_header_contains_label(self):
        out = self._cooldown(duration=0, label="Pre-fetch cooldown")
        assert "Pre-fetch cooldown" in out

    def test_default_label(self):
        out = self._cooldown(duration=0)
        assert "SoC Cooldown" in out

    def test_countdown_lines_verbose(self):
        out = self._cooldown(duration=3, verbose=True)
        # Each remaining second (3, 2, 1) should produce a line
        assert out.count("remaining") == 3

    def test_verbose_mentions_duration(self):
        out = self._cooldown(duration=5, verbose=True)
        assert "5s" in out

    def test_ready_banner_always_present(self):
        for d in (0, 1, 5):
            out = self._cooldown(duration=d)
            assert "Ready" in out, f"No ready banner for duration={d}"

    def test_return_value_is_none(self):
        import io
        from repo_sorter.cooldown import run_cooldown

        result = run_cooldown(duration=0, _stream=io.StringIO(), _tick=0)
        assert result is None

    def test_negative_duration_raises_value_error(self):
        import io
        import pytest
        from repo_sorter.cooldown import run_cooldown

        with pytest.raises(ValueError):
            run_cooldown(duration=-1, _stream=io.StringIO(), _tick=0)


# ---------------------------------------------------------------------------
# Cooldown – CLI integration tests
# ---------------------------------------------------------------------------


class TestCooldownCLI:
    def _run(self, args, db_path, capsys):
        from repo_sorter.cli import main

        rc = main(["--db", db_path] + args)
        out, err = capsys.readouterr()
        return rc, out, err

    def test_cooldown_zero_duration(self, db_path, capsys):
        rc, out, _ = self._run(["cooldown", "--duration", "0"], db_path, capsys)
        assert rc == 0
        assert "Ready" in out

    def test_cooldown_custom_label(self, db_path, capsys):
        rc, out, _ = self._run(
            ["cooldown", "--duration", "0", "--label", "Pre-agent pause"],
            db_path,
            capsys,
        )
        assert rc == 0
        assert "Pre-agent pause" in out

    def test_cooldown_verbose_flag(self, db_path, capsys, monkeypatch):
        # Patch time.sleep to skip real waiting and _tick cannot be set via CLI
        # so we monkeypatch time.sleep instead
        monkeypatch.setattr("time.sleep", lambda _: None)
        rc, out, _ = self._run(
            ["cooldown", "--duration", "2", "--verbose"],
            db_path,
            capsys,
        )
        assert rc == 0
        assert "remaining" in out

    def test_cooldown_short_form_flags(self, db_path, capsys):
        rc, out, _ = self._run(["cooldown", "-n", "0", "-l", "Quick cool"], db_path, capsys)
        assert rc == 0
        assert "Quick cool" in out

    def test_cooldown_negative_duration_returns_error(self, db_path, capsys):
        rc, _, err = self._run(["cooldown", "--duration", "-1"], db_path, capsys)
        assert rc == 1
        assert "--duration must be 0 or greater" in err
