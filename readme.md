# Installation
The pipeline is orchestrated by [SnakeMake](https://snakemake.readthedocs.io) and the *snakefile* in the root folder of this repository. This means SnakeMake must be installed:
```
pip install snakemake
```
Note: this uses **Python 3.6** or more recent.

# Configuration
The configuration of the pipeline is written in the file `config.yaml`.  
Before running the pipeline, make sure you modify:
- `WORKING_DIR` with a directory of your choice (will contain all the files, temporary or not)
- `NEXUS_TOKEN_FILE` with a local text file of yours that contains the token
- optionally `NEXUS_IDS_FILE` if the @ids have changed or if you are using a different Nexus environment

If you do not want to modify the config file, you can still overload the config settings when running the pipeline in command line using the `--config` flag:
```
snakemake --config RESOLUTION="10" --forcerun some_rule
```

# Launch the pipeline
In a terminal, first `cd` the *workflow* folder:
```
cd blue_brain_atlas_pipeline
```

Then, based on whether the whole pipeline or just a subpart of it needs to be launched, it can be handy to have the list of the tasks available:

- `fetch_ccf_brain_region_hierarchy`, using **bba-datafetch** CLI
- `fetch_brain_parcellation_ccfv2`, using **bba-datafetch`** CLI
- `fetch_fiber_parcellation_ccfv2`, using **bba-datafetch** CLI
- `fetch_brain_parcellation_ccfv3`, using **bba-datafetch** CLI
- `fetch_gene_tmem119`, using **bba-datafetch** CLI
- `fetch_gene_s100b`, using **bba-datafetch** CLI
- `fetch_gene_nrn1`, using **bba-datafetch** CLI
- `fetch_gene_gfap`, using **bba-datafetch** CLI
- `fetch_gene_gad`, using **bba-datafetch** CLI
- `fetch_gene_gad`, using **bba-datafetch** CLI
- `fetch_gene_aldh1l1`, using **bba-datafetch** CLI
- `combine`, FAKE TASK (because module not ready yet)

Note: the pipeline framework (Snakemake) resolves the data dependencies and automatically schedules the tasks to be launched when data are missing. Hence, there is no need to launch all the tasks manually, only the target one.

Then to launch the pipeline up to a certain task:
```
snakemake --forcerun some_rule
```
where `some_rule` is the actual name of a rule, such as `combine`
