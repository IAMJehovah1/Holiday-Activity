# Medical Repository Sorting Tool

> Sort, categorize, and manage your GitHub repositories with a focus on healthcare and medical tooling.

---

## Overview

`repo-sorter` is a lightweight Python CLI tool that helps you organize your GitHub repositories into a structured, medically-focused catalogue.  
You can assign categories, add free-form tags, store metadata, and filter your repositories in seconds — all from your terminal.

It works entirely offline with a local JSON database (default: `~/.repo_sorter/repos.json`), and can also connect to the GitHub API to automatically import and categorize your public or private repositories.

---

## Features

| Feature | Description |
|---|---|
| **15 built-in medical categories** | EHR, diagnostics, telemedicine, pharmacology, medical imaging, and more |
| **Custom categories** | Add, update, or remove your own categories at any time |
| **Free-form tagging** | Attach any number of tags to a repository |
| **Flexible filtering** | Filter by category, tags (AND logic), or keyword search |
| **Auto-categorisation** | Automatically assigns a medical category from description text and GitHub topics |
| **GitHub import** | Fetch all your GitHub repositories in one command |
| **Export to JSON / CSV** | Share or back up your catalogue |
| **No external dependencies** | Runs on Python 3.8+ with the standard library only |

---

## Quick Start

### 1 — Clone or copy the tool

```bash
git clone https://github.com/IAMJehovah1/Holiday-Activity.git
cd Holiday-Activity
```

### 2 — (Optional) install in editable mode

```bash
pip install -e .
```

This makes the `repo-sorter` command available system-wide.  
Without installation you can still run: `python -m repo_sorter <command>`.

### 3 — Verify the installation

```bash
repo-sorter --help
```

---

## Usage

```
repo-sorter [--db PATH] <command> [options]
```

| Option | Description |
|---|---|
| `--db PATH` | Override the default database path (`~/.repo_sorter/repos.json`) |

### Commands at a glance

| Command | Description |
|---|---|
| `add` | Add a repository manually |
| `remove` / `rm` | Remove a repository |
| `list` / `ls` | List repositories (with optional filters) |
| `show` | Show full details for one repository |
| `update` | Update fields on an existing repository |
| `tag` | Add or remove tags |
| `categorize` | Assign a category to a repository |
| `categories list` | Show all available categories |
| `categories add` | Add a custom category |
| `categories remove` | Remove a custom category |
| `fetch` | Import repositories from GitHub |
| `export` | Export catalogue to JSON or CSV |
| `import` | Import catalogue from a JSON file |

---

## Examples

### Add a repository manually

```bash
repo-sorter add owner/my-ehr-system \
  --category ehr \
  --tags "fhir,hl7,openehr" \
  --description "Open-source EHR built on FHIR R4" \
  --url "https://github.com/owner/my-ehr-system"
```

### Auto-detect the category from the description

```bash
repo-sorter add owner/dicom-viewer \
  --description "DICOM image viewer for radiology departments" \
  --auto-categorize
# Auto-detected category: medical-imaging
```

### List all repositories

```bash
repo-sorter list
```

### Filter by category

```bash
repo-sorter list --category ehr
```

### Filter by tag

```bash
repo-sorter list --tags fhir
```

### Filter by multiple tags (AND logic)

```bash
repo-sorter list --tags "fhir,hl7"
```

### Search by keyword

```bash
repo-sorter list --search imaging
```

### Show full details for a repository

```bash
repo-sorter show owner/my-ehr-system
```

### Update fields on a repository

```bash
repo-sorter update owner/my-ehr-system \
  --description "Updated description" \
  --category ehr \
  --tags "fhir,hl7,cda"
```

### Add tags without replacing existing ones

```bash
repo-sorter tag owner/my-ehr-system --tags "openehr,snomed"
```

### Remove specific tags

```bash
repo-sorter tag owner/my-ehr-system --tags "snomed" --remove
```

### Assign a category

```bash
repo-sorter categorize owner/my-ehr-system ehr
```

### Remove a repository

```bash
repo-sorter remove owner/my-ehr-system
```

---

## Fetch from GitHub

Automatically import **all** repositories for a GitHub user or organisation and let the tool assign medical categories based on repository descriptions and topics.

```bash
# Public repos only
repo-sorter fetch octocat

# Public + private repos (requires a personal access token)
export GITHUB_TOKEN=ghp_your_token_here
repo-sorter fetch myorg

# Disable auto-categorisation
repo-sorter fetch myorg --no-auto-categorize
```

---

## Export & Import

### Export to JSON

```bash
repo-sorter export --output my-repos.json
```

### Export to CSV (for spreadsheets)

```bash
repo-sorter export --output my-repos.csv --format csv
```

### Import from a JSON file

```bash
repo-sorter import my-repos.json
# Use --overwrite to replace existing entries
repo-sorter import my-repos.json --overwrite
```

---

## Managing Categories

### List all categories

```bash
repo-sorter categories list
```

**Built-in medical categories:**

| Key | Description |
|---|---|
| `diagnostics` | Tools for medical diagnosis, test analysis, lab results |
| `ehr` | Electronic Health Record systems, FHIR integrations |
| `telemedicine` | Remote healthcare delivery, telehealth apps |
| `pharmacology` | Drug databases, dosage calculators, medication management |
| `research` | Medical research, clinical trials, biostatistics |
| `patient-management` | Patient scheduling, care coordination |
| `medical-imaging` | DICOM viewers, radiology tools, pathology imaging |
| `wearables` | Health monitoring devices, wearable sensor integrations |
| `mental-health` | Mental health platforms, therapy tools, mood tracking |
| `emergency` | Emergency response, triage systems, EMS dispatch |
| `genomics` | Genomics, bioinformatics, DNA analysis |
| `nutrition` | Dietary tracking, nutrition analysis, wellness tools |
| `rehabilitation` | Physical therapy, occupational therapy, rehab management |
| `general-healthcare` | General healthcare utilities, hospital management |
| `other` | Miscellaneous or uncategorized repositories |

### Add a custom category

```bash
repo-sorter categories add ai-health "AI and machine learning tools for healthcare"
```

### Remove a custom category

```bash
repo-sorter categories remove ai-health
```

Custom categories are stored in `~/.repo_sorter/custom_categories.json` and persist across sessions.

---

## Data Storage

All data is stored locally:

| File | Purpose |
|---|---|
| `~/.repo_sorter/repos.json` | Main repository catalogue |
| `~/.repo_sorter/custom_categories.json` | Custom category definitions |

Use `--db PATH` to point to a different database (useful for team/org workflows or CI pipelines).

---

## Use in an Organisation Workflow

```bash
# Fetch all org repositories and categorize them
repo-sorter --db ./org-repos.json fetch my-health-org --token "$GITHUB_TOKEN"

# Filter to only EHR projects
repo-sorter --db ./org-repos.json list --category ehr

# Export for review
repo-sorter --db ./org-repos.json export --output ./org-ehr-repos.csv --format csv
```

Commit `org-repos.json` to your repository to share the catalogue with your team.

---

## iPad Pro M2 Setup (Cooldown Workflow)

Use this when running heavy Copilot/search tasks from an iPad Pro M2.

### 1) Choose your environment

- iPad terminal with Python 3.8+ (for example, iSH or a-Shell), or
- GitHub Codespaces opened from Safari on iPad.

### 2) Clone and install

```bash
git clone https://github.com/IAMJehovah1/Holiday-Activity.git
cd Holiday-Activity
pip install -e .
```

### 3) Run cooldown before heavy tasks

```bash
# Module form
python -m repo_sorter cooldown --duration 30

# Installed CLI form
repo-sorter cooldown --duration 30
```

### 4) Tune for your workflow

```bash
# Custom label
repo-sorter cooldown --duration 45 --label "Pre-search cooldown"

# Verbose output (one line per second)
repo-sorter cooldown --duration 20 --verbose
```

### 5) Daily routine

Run the cooldown command immediately before intensive Copilot/search sessions so your M2 SoC can settle to a more stable thermal baseline.

---

## Running the Tests

```bash
pip install pytest
pytest tests/ -v
```

---

## Project Structure

```
Holiday-Activity/
├── repo_sorter/
│   ├── __init__.py          # Package metadata
│   ├── __main__.py          # python -m repo_sorter entry point
│   ├── cli.py               # CLI argument parsing and command handlers
│   ├── sorter.py            # Core data model, CRUD, auto-categorisation
│   └── data/
│       └── categories.json  # Built-in medical category definitions
├── tests/
│   └── test_repo_sorter.py  # Unit and integration tests (61 tests)
├── setup.py                 # Package setup
├── requirements.txt
└── README.md
```

---

## License

MIT
