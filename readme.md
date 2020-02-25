# Launch the pipeline

```
snakemake -n --use-conda
```

The `config.yaml` file contains a default config but all the arguments can be overloaded with the `--config` flag:
```
snakemake --config RESOLUTION="10" snakemake --forcerun some_rule
```

Run
