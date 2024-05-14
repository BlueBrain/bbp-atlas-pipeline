from pathlib import Path
from kgforge.core import KnowledgeGraphForge
from cellCompVolume_payload import create_payload

with open(snakemake.log[0], "w") as logfile:
    total_densities = 0
    for folder in snakemake.params.input_paths:
        n_densities = len(list(Path(folder).rglob("*" + snakemake.params.files_ext)))
        logfile.write(f"\nAdding {n_densities} from {folder}")
        total_densities += n_densities
    logfile.write(f"\nExpecting {total_densities} densities in the CellCompositionVolume payload\n")

    forge = KnowledgeGraphForge(snakemake.params.forge_config, bucket=snakemake.params.nexus_bucket,
                                endpoint=snakemake.params.nexus_env, token=snakemake.params.nexus_token)

    logfile.write(
        f"Creating CellCompositionVolume payload for atlasRelease {snakemake.params.atlas_release_id} "
        f"with tag '{snakemake.params.resource_tag}' from endpoint '{snakemake.params.nexus_env}'\n")
    create_payload(forge, snakemake.params.atlas_release_id, snakemake.output.payload, total_densities,
        endpoint=snakemake.params.nexus_env, bucket=snakemake.params.nexus_bucket, tag=snakemake.params.resource_tag)
    logfile.write(f"CellCompositionVolume payload created: {snakemake.output.payload}\n")
