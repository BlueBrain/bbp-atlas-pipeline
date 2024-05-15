import json
from kgforge.core import KnowledgeGraphForge
from blue_cwl import staging, statistics
import multiprocessing
import voxcell


with open(snakemake.log[0], "w") as logfile:
    logfile.write(f"Reading CellCompositionVolume payload from {snakemake.input.cellCompositionVolume}\n")
    with open(snakemake.input.cellCompositionVolume) as volume_json:
        volume_dict = json.load(volume_json)
        nexus_endpoint = snakemake.params.nexus_env
        forge = KnowledgeGraphForge(snakemake.params.forge_config, bucket=snakemake.params.nexus_bucket,
                                    endpoint=nexus_endpoint, token=snakemake.params.nexus_token)

        logfile.write(f"Creating density_distribution from endpoint '{nexus_endpoint}' in {snakemake.output.intermediate_density_distribution}\n")
        density_distribution = staging.materialize_density_distribution(forge=forge, dataset=volume_dict,
            output_file=snakemake.output.intermediate_density_distribution)

        logfile.write(f"Computing CellCompositionSummary payload for endpoint '{nexus_endpoint}'\n")

        with multiprocessing.Pool(processes=snakemake.params.cores) as pool:
            summary_statistics = statistics.atlas_densities_composition_summary(density_distribution,
                voxcell.RegionMap.load_json(snakemake.input.hierarchy),
                voxcell.VoxelData.load_nrrd(snakemake.input.annotation),
                map_function=pool.imap)
            logfile.write(f"Writing CellCompositionSummary payload in {snakemake.output.summary_statistics}\n")
            with open(snakemake.output.summary_statistics, "w") as outfile:
                outfile.write(json.dumps(summary_statistics, indent=4))
