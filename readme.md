# Launch the pipeline
In a terminal, first `cd` the *workflow* folder:
```
cd blue_brain_atlas_pipeline
```

Then, based on whether the whole pipeline or just a subpart of it needs to be launched, it can be handy to have the list of the tasks available:

- `fetch_ccf_brain_region_hierarchy`, using `bba-datafetch`
- `fetch_brain_parcellation_ccfv2`, using `bba-datafetch`
- `fetch_fiber_parcellation_ccfv2`, using `bba-datafetch`
- `fetch_brain_parcellation_ccfv3`, using `bba-datafetch`
- `combine`, FAKE TASK (because module not ready yet)

Note: the pipeline framework (Snakemake) resolves the data dependencies and automatically schedules the tasks to be launched when data are missing. Hence, there is no need to launch all the tasks manually, only the target one.

Then to launch the pipeline up to a certain task:
```
snakemake --forcerun some_rule
```
where `some_rule` is the actual name of a rule, such as `combine`

# configuration
The `workflow/config.yaml` file contains a default config but all the arguments can be overloaded with the `--config` flag:
```
snakemake --config RESOLUTION="10" snakemake --forcerun some_rule
```
