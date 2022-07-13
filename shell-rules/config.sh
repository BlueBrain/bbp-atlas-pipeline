# ------------------------------ NEXUS CONFIG  ---------------------------------------------------------

# Were to find the Nexus access token. This path is actually the default by the CLI blue-brain-token-fetch
export TOKEN_FILE="$HOME/.token_fetch/Token"

# The Nexus Forge configuration is included in this directory
export FORGE_CONFIG="$BASEDIR/forge-config.yml"

# The pipeline will fetch the necessary datasets from:
export NEXUS_ATLAS_ENV="https://bbp.epfl.ch/nexus/v1"
export NEXUS_ATLAS_ORG="bbp"
export NEXUS_ATLAS_PROJ="atlas"
export NEXUS_ONTOLOGY_ORG="neurosciencegraph"
export NEXUS_ONTOLOGY_PROJ="datamodels"

# The pipeline will push the generated datasets into:
# export NEXUS_DESTINATION_ENV="https://staging.nise.bbp.epfl.ch/nexus/v1"
# export NEXUS_DESTINATION_ORG="bbp"
# export NEXUS_DESTINATION_PROJ="atlas"

export NEXUS_DESTINATION_ENV="https://bbp.epfl.ch/nexus/v1"
export NEXUS_DESTINATION_ORG="bbp"
export NEXUS_DESTINATION_PROJ="atlas"

# ------------------------------ NEXUS DATASETS IDs  ---------------------------------------------------------

export NEXUS_ID_ONTOLOGY_MOUSE_CCF="http://bbp.epfl.ch/neurosciencegraph/ontologies/core/mba_brainregion_corrected"
export NEXUS_ID_ANNOTATION_VOLUME_MOUSE_CCF_V2_BRAIN="https://bbp.epfl.ch/neurosciencegraph/data/7b4b36ad-911c-4758-8686-2bf7943e10fb"
export NEXUS_ID_ANNOTATION_VOLUME_MOUSE_CCF_V2_FIBER="https://bbp.epfl.ch/neurosciencegraph/data/a4552116-607b-469e-ad2a-50bba00c23d8"
export NEXUS_ID_ANNOTATION_VOLUME_MOUSE_CCF_V3_BRAIN="https://bbp.epfl.ch/neurosciencegraph/data/025eef5f-2a9a-4119-b53f-338452c72f2a"
export NEXUS_ID_TEMPLATE_VOLUME_MOUSE_CCF_V3="https://bbp.epfl.ch/neurosciencegraph/data/dca40f99-b494-4d2c-9a2f-c407180138b7"
export NEXUS_ID_AIBS_MOUSE_CCF_SRS="https://bbp.epfl.ch/neurosciencegraph/data/allen_ccfv3_spatial_reference_system"

export NEXUS_ID_NISSL_STACK_CORONAL_CCF_V2="https://bbp.epfl.ch/neurosciencegraph/data/ae8cbd28-e17b-4c1e-967a-a5084b7ad335"
export NEXUS_ID_NISSL_ANNOTATION_STACK_CORONAL_CCF_V2="https://bbp.epfl.ch/neurosciencegraph/data/d45f1a66-e663-4991-bda9-3ee8bc447061"

export NEXUS_ID_GENE_EXPRESSION_VOLUME_aldh1l1="https://bbp.epfl.ch/neurosciencegraph/data/9e2c3aa7-3b19-4da6-9623-f864368326e6"
export NEXUS_ID_GENE_EXPRESSION_VOLUME_cnp="https://bbp.epfl.ch/neurosciencegraph/data/dfaaece4-04b9-49c9-9561-6141f4e9c848"
export NEXUS_ID_GENE_EXPRESSION_VOLUME_mbp="https://bbp.epfl.ch/neurosciencegraph/data/96db5934-e9ef-47e8-bc66-3624509ddaeb"
export NEXUS_ID_GENE_EXPRESSION_VOLUME_gad="https://bbp.epfl.ch/neurosciencegraph/data/50b8e911-6d97-4a82-910b-325273cafed6"
export NEXUS_ID_GENE_EXPRESSION_VOLUME_gfap="https://bbp.epfl.ch/neurosciencegraph/data/a7b63363-742e-4671-826f-3a2b82db17c6"
export NEXUS_ID_GENE_EXPRESSION_VOLUME_nrn1="https://bbp.epfl.ch/neurosciencegraph/data/6951d06f-6be9-45f5-a2f3-d4001af9cca5"
export NEXUS_ID_GENE_EXPRESSION_VOLUME_s100b="https://bbp.epfl.ch/neurosciencegraph/data/db7b9f14-0942-4131-8ef7-ab02b1497469"
export NEXUS_ID_GENE_EXPRESSION_VOLUME_tmem119="https://bbp.epfl.ch/neurosciencegraph/data/6e3e0700-7289-4285-ba5c-3ac94930f3d7"
export NEXUS_ID_GENE_EXPRESSION_VOLUME_pv="https://bbp.epfl.ch/neurosciencegraph/data/2f53f1b3-73e7-4cf3-8e82-9bb55c7a6443"
export NEXUS_ID_GENE_EXPRESSION_VOLUME_sst="https://bbp.epfl.ch/neurosciencegraph/data/c5a6e50c-8994-4194-bc3a-7254310d5558"
export NEXUS_ID_GENE_EXPRESSION_VOLUME_vip="https://bbp.epfl.ch/neurosciencegraph/data/3bb21391-0ce7-446d-b18f-309b84f955a6"
export NEXUS_ID_GENE_EXPRESSION_VOLUME_gad67="https://bbp.epfl.ch/neurosciencegraph/data/8859cece-c0d0-4776-b638-fb871168880d"
export NEXUS_ID_GENE_EXPRESSION_VOLUME_pv_correctednissl="https://bbp.epfl.ch/neurosciencegraph/data/e758bb5f-d455-457c-90b8-345d5f9abdb2"
export NEXUS_ID_GENE_EXPRESSION_VOLUME_sst_correctednissl="https://bbp.epfl.ch/neurosciencegraph/data/423e277c-259b-410a-bf07-4752be66ae33"
export NEXUS_ID_GENE_EXPRESSION_VOLUME_vip_correctednissl="https://bbp.epfl.ch/neurosciencegraph/data/a3c77f3f-3cb4-4b19-95f3-92b2330dfdb8"
export NEXUS_ID_GENE_EXPRESSION_VOLUME_gad67_correctednissl="https://bbp.epfl.ch/neurosciencegraph/data/e51f53c8-6883-49e5-8a5b-eec4bd7d41c3"

# ------------------------------ LOCAL FILEPATHS -------------------------------------------------------------
# The following paths are where data is going to be locally created. Those paths are kept as variables because
# they later on need to the known by the CLI pushing data back to Nexus.

# The working directory is were all the file (temporary or not) will be written.
# export WORKING_DIR="$HOME/working_dir_atlas"
export WORKING_DIR="$HOME/Documents/BBP/data/atlas-pipeline/working_dir3"

# Path to the local copy of the CCF v3 annotation volume
export FETCHED_ANNOTATION_VOLUME_MOUSE_CCF_V3_BRAIN="$WORKING_DIR/brain_parcellation_ccfv3.nrrd"

# Path to the local copy of the average brain TEMPLATE from CCF v3
export FETCHED_TEMPLATE_VOLUME_MOUSE_CCF_V3="$WORKING_DIR/brain_template_ccfv3.nrrd"

# Path to the local copy of the Mouse CCF brain region ontology file (aka. 1.json)
export FETCHED_ONTOLOGY_MOUSE_CCF="$WORKING_DIR/hierarchy.json"

# Path to the computed volume of direction vectors
export COMPUTED_VOLUME_DIRECTION_VECTOR_ISOCORTEX="$WORKING_DIR/direction_vectors_isocortex_ccfv3.nrrd"

# Path to the computed volume of orientation field (same as direction vectors, but as quaternions)
export COMPUTED_VOLUME_ORIENTATION_FIELD_ISOCORTEX="$WORKING_DIR/orientation_field_isocortex_ccfv3.nrrd"

# Path to the computed ontology containing the split of L2/L3 isocortex regions
export COMPUTED_ONTOLOGY_MOUSE_CCF_SPLIT_L2L3="$WORKING_DIR/hierarchy_split_L2L3.json"

# Path to the computed ontology containing the split of L2/L3 isocortex regions, in JSON-LD format
export COMPUTED_ONTOLOGY_MOUSE_CCF_SPLIT_L2L3_JSONLD="$WORKING_DIR/hierarchy_split_L2L3_LD.json"

# Path to the computed brain annotation volume containing the split of L2/L3 isocortex regions
export COMPUTED_ANNOTATION_VOLUME_MOUSE_CCF_V3_BRAIN_SPLIT_L2L3="$WORKING_DIR/brain_parcellation_ccfv3_split_L2L3.nrrd"

# Directory to save the meshes of brain regions
export COMPUTED_ANNOTATION_MESHES_DIR="$WORKING_DIR/annotation_meshes"

# Directory to save the masks of brain regions
export COMPUTED_ANNOTATION_MASKS_DIR="$WORKING_DIR/annotation_masks"

# Path for the file containing brain region information (future summary cards)
export COMPUTED_REGIONS_METADATA="$WORKING_DIR/regions_metadata.json"

# Path for the directory containing the placement hints
export COMPUTED_PLACEMENT_HINTS_DIR="$WORKING_DIR/placement_hints"

# This file contains the Nexus Resource ID of the AtlasRelease created by this pipeline.
# This file is create by push_atlasrelease.py
export PUSHED_ATLAS_RELEASE_ID_TXT_FILE="$WORKING_DIR/new_atlas_release_id.txt"
