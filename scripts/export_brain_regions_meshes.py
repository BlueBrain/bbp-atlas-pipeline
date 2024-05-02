import os

mesh_dir_option = ""
if snakemake.params.export_meshes:
    mesh_dir_option = f" --out-mesh-dir {snakemake.output.mesh_dir}"
else:
    os.makedirs(snakemake.output.mesh_dir, exist_ok=True)

shell_command = f"""{snakemake.params.app}  \
    --hierarchy {snakemake.input.hierarchy}  \
    --parcellation-volume {snakemake.input.annotation}  \
    --region-layer-map {snakemake.input.region_layer_map}  \
    {mesh_dir_option}  \
    --out-mask-dir {snakemake.output.mask_dir}  \
    --out-metadata {snakemake.output.json_metadata_parcellations}  \
    --out-hierarchy-volume {snakemake.output.hierarchy_volume}  \
    --out-hierarchy-jsonld {snakemake.output.hierarchy_jsonld}  \
    2>&1 | tee {snakemake.log[0]}"""

os.system(shell_command)
