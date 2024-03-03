import shutil
from customize_pipeline.customize_pipeline import main

# merge default output and single-region outputs into a merged file
main(snakemake.input.hierarchy, snakemake.input.annotation, snakemake.params.user_rule,
     snakemake.input.default_output_dir, snakemake.output.dir,
     snakemake.input.default_output_file, snakemake.params.metadata_path)
# replace the default output with the merged file
shutil.copytree(snakemake.output.dir, snakemake.input.default_output_dir, dirs_exist_ok=True)
