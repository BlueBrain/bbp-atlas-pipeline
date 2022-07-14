# current directory where this very script is
export BASEDIR=$(dirname "$0")

# Loading the variables
source $BASEDIR/config.sh


echo "______________________________________________________________________________________"
echo "   Please make sure you run the CLI blue-brain-token-fetch in the background before   "
echo "______________________________________________________________________________________" 

# reading the token from the file
ACCESS_TOKEN=`cat $TOKEN_FILE`

# Creating the working directory if not already present
mkdir -p $WORKING_DIR


# --------------------------------------------------------------------------------- #
#                              FETCHING FROM NEXUS                                  #
# --------------------------------------------------------------------------------- #


echo "📥 Fetching brain annotation volume..."
bba-data-fetch --nexus-env $NEXUS_ATLAS_ENV \
  --nexus-token $ACCESS_TOKEN \
  --nexus-org $NEXUS_ATLAS_ORG \
  --nexus-proj $NEXUS_ATLAS_PROJ \
  --out $FETCHED_ANNOTATION_VOLUME_MOUSE_CCF_V3_BRAIN \
  --nexus-id $NEXUS_ID_ANNOTATION_VOLUME_MOUSE_CCF_V3_BRAIN \
  --verbose


echo "📥 Fetching brain average template volume..."
bba-data-fetch --nexus-env $NEXUS_ATLAS_ENV \
  --nexus-token $ACCESS_TOKEN \
  --nexus-org $NEXUS_ATLAS_ORG \
  --nexus-proj $NEXUS_ATLAS_PROJ \
  --out $FETCHED_TEMPLATE_VOLUME_MOUSE_CCF_V3 \
  --nexus-id $NEXUS_ID_TEMPLATE_VOLUME_MOUSE_CCF_V3 \
  --verbose 


echo "📥 Fetching brain region ontology..."
bba-data-fetch --nexus-env $NEXUS_ATLAS_ENV \
  --nexus-token $ACCESS_TOKEN \
  --nexus-org $NEXUS_ONTOLOGY_ORG \
  --nexus-proj $NEXUS_ONTOLOGY_PROJ \
  --out $FETCHED_ONTOLOGY_MOUSE_CCF \
  --nexus-id $NEXUS_ID_ONTOLOGY_MOUSE_CCF \
  --favor name:1.json \
  --verbose


# --------------------------------------------------------------------------------- #
#                                COMPUTING DATA                                     #
# --------------------------------------------------------------------------------- #


echo "🤖 Computing direction vectors for isocortex..."
atlas-building-tools direction-vectors isocortex --annotation-path $FETCHED_ANNOTATION_VOLUME_MOUSE_CCF_V3_BRAIN \
  --hierarchy-path $FETCHED_ONTOLOGY_MOUSE_CCF \
  --output-path $COMPUTED_VOLUME_DIRECTION_VECTOR_ISOCORTEX


echo "🤖 Computing orientation fields for isocortex..."
atlas-building-tools orientation-field  --direction-vectors-path $COMPUTED_VOLUME_DIRECTION_VECTOR_ISOCORTEX \
  --output-path $COMPUTED_VOLUME_ORIENTATION_FIELD_ISOCORTEX


echo "🤖 Computing splitting L2/L3 from isocortex..."
atlas-building-tools region-splitter split-isocortex-layer-23 --hierarchy-path $FETCHED_ONTOLOGY_MOUSE_CCF \
  --annotation-path $FETCHED_ANNOTATION_VOLUME_MOUSE_CCF_V3_BRAIN \
  --direction-vectors-path $COMPUTED_VOLUME_DIRECTION_VECTOR_ISOCORTEX \
  --output-hierarchy-path $COMPUTED_ONTOLOGY_MOUSE_CCF_SPLIT_L2L3 \
  --output-annotation-path $COMPUTED_ANNOTATION_VOLUME_MOUSE_CCF_V3_BRAIN_SPLIT_L2L3


echo "🤖 Computing placement hints..."
mkdir -p $COMPUTED_PLACEMENT_HINTS_DIR
atlas-building-tools placement-hints isocortex --annotation-path $COMPUTED_ANNOTATION_VOLUME_MOUSE_CCF_V3_BRAIN_SPLIT_L2L3 \
  --hierarchy-path $COMPUTED_ONTOLOGY_MOUSE_CCF_SPLIT_L2L3 \
  --direction-vectors-path $COMPUTED_VOLUME_DIRECTION_VECTOR_ISOCORTEX \
  --output-dir $COMPUTED_PLACEMENT_HINTS_DIR \
  --algorithm voxel-based


echo "🤖 Computing region meshes and masks..."
mkdir -p $COMPUTED_ANNOTATION_MESHES_DIR
mkdir -p $COMPUTED_ANNOTATION_MASKS_DIR
parcellationexport --hierarchy $COMPUTED_ONTOLOGY_MOUSE_CCF_SPLIT_L2L3 \
  --parcellation-volume $COMPUTED_ANNOTATION_VOLUME_MOUSE_CCF_V3_BRAIN_SPLIT_L2L3 \
  --out-mesh-dir $COMPUTED_ANNOTATION_MESHES_DIR \
  --out-mask-dir $COMPUTED_ANNOTATION_MASKS_DIR \
  --out-metadata $COMPUTED_REGIONS_METADATA \
  --out-hierarchy-jsonld $COMPUTED_ONTOLOGY_MOUSE_CCF_SPLIT_L2L3_JSONLD


# --------------------------------------------------------------------------------- #
#                              PUSHING TO NEXUS                                     #
# --------------------------------------------------------------------------------- #


echo "📤 pushing AtlasRelease and its components onto Nexus..."
# reading the token from the file
ACCESS_TOKEN=`cat $TOKEN_FILE`
python $BASEDIR/push_atlasrelease.py --forge-config $FORGE_CONFIG \
  --nexus-env $NEXUS_DESTINATION_ENV \
  --nexus-org $NEXUS_DESTINATION_ORG \
  --nexus-proj $NEXUS_DESTINATION_PROJ \
  --access-token $ACCESS_TOKEN \
  --nexus-id-aibs-ccf-srs $NEXUS_ID_AIBS_MOUSE_CCF_SRS \
  --hierarchy $COMPUTED_ONTOLOGY_MOUSE_CCF_SPLIT_L2L3 \
  --hierarchy-ld $COMPUTED_ONTOLOGY_MOUSE_CCF_SPLIT_L2L3_JSONLD \
  --annotation-volume $COMPUTED_ANNOTATION_VOLUME_MOUSE_CCF_V3_BRAIN_SPLIT_L2L3 \
  --template-volume $FETCHED_TEMPLATE_VOLUME_MOUSE_CCF_V3 \
  --out-atlasrelease-id-file $PUSHED_ATLAS_RELEASE_ID_TXT_FILE


echo "📤 pushing placement hints and orientation volumes onto Nexus..."
ACCESS_TOKEN=`cat $TOKEN_FILE`
ATLAS_RELEASE_ID=`cat $PUSHED_ATLAS_RELEASE_ID_TXT_FILE`
python $BASEDIR/push_non_mask_volumes.py --forge-config $FORGE_CONFIG \
  --nexus-env $NEXUS_DESTINATION_ENV \
  --nexus-org $NEXUS_DESTINATION_ORG \
  --nexus-proj $NEXUS_DESTINATION_PROJ \
  --access-token $ACCESS_TOKEN \
  --nexus-id-aibs-ccf-srs $NEXUS_ID_AIBS_MOUSE_CCF_SRS \
  --atlasrelease-id $ATLAS_RELEASE_ID \
  --hierarchy $COMPUTED_ONTOLOGY_MOUSE_CCF_SPLIT_L2L3 \
  --direction-vector-volume $COMPUTED_VOLUME_DIRECTION_VECTOR_ISOCORTEX \
  --orientation-field-volume $COMPUTED_VOLUME_ORIENTATION_FIELD_ISOCORTEX \
  --placement-hints-volume-dir $COMPUTED_PLACEMENT_HINTS_DIR


echo "📤 pushing regions mask onto Nexus..."
# reading the token from the file
ACCESS_TOKEN=`cat $TOKEN_FILE`
ATLAS_RELEASE_ID=`cat $PUSHED_ATLAS_RELEASE_ID_TXT_FILE`
python $BASEDIR/push_region_masks.py --forge-config $FORGE_CONFIG \
  --nexus-env $NEXUS_DESTINATION_ENV \
  --nexus-org $NEXUS_DESTINATION_ORG \
  --nexus-proj $NEXUS_DESTINATION_PROJ \
  --access-token $ACCESS_TOKEN \
  --nexus-id-aibs-ccf-srs $NEXUS_ID_AIBS_MOUSE_CCF_SRS \
  --atlasrelease-id $ATLAS_RELEASE_ID \
  --hierarchy $COMPUTED_ONTOLOGY_MOUSE_CCF_SPLIT_L2L3 \
  --region-mask-volume-dir $COMPUTED_ANNOTATION_MASKS_DIR


echo "📤 pushing regions meshes onto Nexus..."
# reading the token from the file
ACCESS_TOKEN=`cat $TOKEN_FILE`
ATLAS_RELEASE_ID=`cat $PUSHED_ATLAS_RELEASE_ID_TXT_FILE`
python $BASEDIR/push_region_meshes.py --forge-config $FORGE_CONFIG \
  --nexus-env $NEXUS_DESTINATION_ENV \
  --nexus-org $NEXUS_DESTINATION_ORG \
  --nexus-proj $NEXUS_DESTINATION_PROJ \
  --access-token $ACCESS_TOKEN \
  --nexus-id-aibs-ccf-srs $NEXUS_ID_AIBS_MOUSE_CCF_SRS \
  --atlasrelease-id $ATLAS_RELEASE_ID \
  --hierarchy $COMPUTED_ONTOLOGY_MOUSE_CCF_SPLIT_L2L3 \
  --region-mesh-dir $COMPUTED_ANNOTATION_MESHES_DIR


echo "📤 pushing regions summaries onto Nexus..."
# reading the token from the file
ACCESS_TOKEN=`cat $TOKEN_FILE`
ATLAS_RELEASE_ID=`cat $PUSHED_ATLAS_RELEASE_ID_TXT_FILE`
python $BASEDIR/push_region_summaries.py --forge-config $FORGE_CONFIG \
  --nexus-env $NEXUS_DESTINATION_ENV \
  --nexus-org $NEXUS_DESTINATION_ORG \
  --nexus-proj $NEXUS_DESTINATION_PROJ \
  --access-token $ACCESS_TOKEN \
  --nexus-id-aibs-ccf-srs $NEXUS_ID_AIBS_MOUSE_CCF_SRS \
  --atlasrelease-id $ATLAS_RELEASE_ID \
  --hierarchy $COMPUTED_ONTOLOGY_MOUSE_CCF_SPLIT_L2L3 \
  --region-metadata $COMPUTED_REGIONS_METADATA