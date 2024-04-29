import os
import yaml

import gitlab
from kgforge.core import KnowledgeGraphForge

resource_id = os.environ["ATLAS_PARCELLATION_ONTOLOGY_ID_STAGING"]
nexus_staging_token = os.environ["NEXUS_STAGING_TOKEN"]
resource_tag = os.environ["RESOURCE_TAG"]
bmo_repo_token = os.environ["BMO_ACCESS_TOKEN"]

forge = KnowledgeGraphForge("forge-config.yml", bucket="bbp/atlas",
    endpoint="https://staging.nise.bbp.epfl.ch/nexus/v1", token=nexus_staging_token)
resource = forge.retrieve(id=resource_id, version=resource_tag)
if not resource:
    raise Exception(f"Tag '{resource_tag}' does not exist for Resource Id {resource_id}")

resource_rev = resource._store_metadata._rev
gl = gitlab.Gitlab('https://bbpgitlab.epfl.ch', private_token=bmo_repo_token)
project = gl.projects.get("dke/apps/brain-modeling-ontology")
target_branch = "develop"
gl_ci = project.files.get(file_path='.gitlab-ci.yml', ref=target_branch)
gl_ci_dict = yaml.safe_load(gl_ci.decode())
ci_var_name = 'ATLAS_PARCELLATION_ONTOLOGY_VERSION_STAGING'
ci_var_value = gl_ci_dict['variables'][ci_var_name]
if ci_var_value == resource_rev:
    raise Exception(f"The current value of {ci_var_name} in branch '{target_branch}' is"
                    f" already {resource_rev}, nothing to update")

print(f"Updating {ci_var_name} from {ci_var_value} to {resource_rev}")
new_branch = "update_atlas_parcellation_ontology"
project.branches.create({'branch': new_branch, 'ref': target_branch})
raw_content = gl_ci.decode()
gl_ci.content = raw_content.decode().replace(f"{ci_var_name}: {ci_var_value}", f"{ci_var_name}: {resource_rev}")
gl_ci.save(branch=new_branch, commit_message=f'Update {ci_var_name} to {resource_rev}')

project.mergerequests.create({
    'source_branch': new_branch,
    'target_branch': target_branch,
    'title': f'Update {ci_var_name}'
})
