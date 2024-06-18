#!/usr/bin/env python
from setuptools import setup, find_packages

setup(
    name="bba_pipeline",
    author="Blue Brain Project, EPFL",
    use_scm_version=True,
    setup_requires=["setuptools_scm"],
    description=(
        "Package defining a SnakeMake pipeline to create the Blue Brain Atlas datasets"
        "and push them into Nexus."
    ),
    license="BBP-internal-confidential",
    python_requires=">=3.9",
    install_requires=[
        "nexusforge>=0.8.2",
        "click>=7.0",
        "numpy>=1.19",
        "pynrrd>=0.4.0",
        "PyYAML>=5.3.1",
        "voxcell",
        "pulp==2.7.0",  # snakemake 7.32.3 breaks with pulp==2.8.0
        "snakemake==7.32.3",
        "blue-brain-token-fetch>=1.0.0",
        "blue-cwl",
        "python-gitlab"
    ],
    extras_require={
        "dev": ["pytest>=4.3", "pytest-cov>=2.8.0"],
        "docs": ["sphinx==7.1.2", "sphinx-bluebrain-theme", "myst-parser"]
    },
    packages=find_packages(),
    include_package_data=True,
    entry_points={
        "console_scripts": ["bbp-atlas=bbp_atlas_cli:execute_pipeline"]
    },
)
