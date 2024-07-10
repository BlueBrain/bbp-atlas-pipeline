import os
import logging

from kgforge.core import KnowledgeGraphForge
from cellCompVolume_payload import create_payload

from blue_cwl.validation import validate_schema

logging.basicConfig(level=logging.INFO)
L = logging.getLogger(__name__)

forge_config = "forge-config.yml" 
nexus_env = "https://staging.nise.bbp.epfl.ch/nexus/v1"
nexus_org = "bbp"
nexus_proj = "atlas"
nexus_token = os.environ["NEXUS_STAGING_TOKEN"]
test_folder = os.environ["TEST_FOLDER"]
tag = "v0.5.1-rc1"
expected_densities = 245
atlasrelease_id = "https://bbp.epfl.ch/neurosciencegraph/data/brainatlasrelease/c96c71a8-4c0d-4bc1-8a1a-141d9ed6693d"


def test_cellCompVolume_payload():
    bucket = "/".join([nexus_org, nexus_proj])
    forge = KnowledgeGraphForge(forge_config, bucket=bucket, endpoint=nexus_env, token=nexus_token)
                       
    output_file = os.path.join(test_folder, "cellCompositionVolume_payload.json")
    payload = create_payload(forge, atlasrelease_id, output_file, expected_densities,
        endpoint=nexus_env, bucket=bucket, tag=tag)
    L.info("Test output: %s" % output_file)

    validate_schema(data=payload, schema_name="cell_composition_volume_distribution.yml")
