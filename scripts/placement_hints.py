import os
import json
from pathlib import Path


def create_placement_hints_metadata(ph_dir, files_ext, region_name, output_path):
    ph_files = [str(path) for path in Path(ph_dir).rglob("*" + files_ext)]
    ph_region_map = {}
    for ph_file in ph_files:
        ph_region_map[os.path.basename(ph_file)] = [region_name]

    with open(output_path, "w") as outfile:
        outfile.write(json.dumps(ph_region_map, indent=4))


shell_command = f"""{snakemake.params.app}  \
    --hierarchy-path {snakemake.input.hierarchy}  \
    --annotation-path {snakemake.input.annotation}  \
    --metadata-path {snakemake.input.region_filter}  \
    --direction-vectors-path {snakemake.input.direction_vectors}  \
    --algorithm voxel-based  \
    --output-dir {snakemake.output.dir}  \
    2>&1 | tee {snakemake.log[0]}"""
# Create Placement hints
os.system(shell_command)
create_placement_hints_metadata(snakemake.output.dir, snakemake.params.files_ext, snakemake.params.region, snakemake.output.metadata)
