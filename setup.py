"""
Setup configuration for the medical repository sorting tool.
"""

from pathlib import Path
from setuptools import setup, find_packages

setup(
    name="repo-sorter",
    version="1.0.0",
    description="Medical Repository Sorting Tool — categorize, tag, and manage GitHub repositories focused on healthcare.",
    long_description=(Path(__file__).parent / "README.md").read_text(encoding="utf-8"),
    long_description_content_type="text/markdown",
    python_requires=">=3.8",
    packages=find_packages(),
    package_data={"repo_sorter": ["data/*.json"]},
    entry_points={
        "console_scripts": [
            "repo-sorter=repo_sorter.cli:main",
        ]
    },
    classifiers=[
        "Development Status :: 4 - Beta",
        "Intended Audience :: Healthcare Industry",
        "Intended Audience :: Developers",
        "Topic :: Scientific/Engineering :: Medical Science Apps.",
        "Programming Language :: Python :: 3",
        "License :: OSI Approved :: MIT License",
    ],
)
