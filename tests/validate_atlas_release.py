import os
import logging
import json
import yaml
from kgforge.core import KnowledgeGraphForge

from bba_data_push.push_atlas_release import validate_atlas_release

logging.basicConfig(level=logging.DEBUG)
logger = logging.getLogger(__name__)

forge_config = "forge-config.yml"
nexus_token = os.environ["NEXUS_TOKEN"]
is_prod_env = os.environ.get("IS_PROD_ENV", False)
nexus_tag = os.environ["RESOURCE_TAG"]
if not nexus_tag:
    nexus_tag = "v1.1.0"

pipeline_config = yaml.safe_load(open("config.yaml").read().strip())
if is_prod_env:
    nexus_env = "prod"
    nexus_endpoint = pipeline_config["NEXUS_PROD_ENV"]
else:
    nexus_env = "staging"
    nexus_endpoint = pipeline_config["NEXUS_STAGING_ENV"]

nexus_ids = json.loads(open("nexus_ids.json").read().strip())
atlas_release_id = nexus_ids["AtlasRelease"][nexus_env]

logger.info(f"Validating AtlasRelease Id {atlas_release_id} at tag '{nexus_tag}' in Nexus {nexus_env} (IS_PROD_ENV: {is_prod_env})")
forge = KnowledgeGraphForge(forge_config, bucket="bbp/atlas", endpoint=nexus_endpoint, token=nexus_token)
validated = validate_atlas_release(atlas_release_id, forge, nexus_tag, logger)
if not validated:
    raise Exception(f"The properties of AtlasRelease Id {atlas_release_id} at "
                    f"tag '{nexus_tag}' did not pass the validation!")
