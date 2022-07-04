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


# Fetching Mouse CCF v3 annotation volume
echo "📥 Fetching brain annotation volume..."
bba-data-fetch --nexus-env $NEXUS_ATLAS_ENV \
  --nexus-token $ACCESS_TOKEN \
  --nexus-org $NEXUS_ATLAS_ORG \
  --nexus-proj $NEXUS_ATLAS_PROJ \
  --out $FETCHED_ANNOTATION_VOLUME_MOUSE_CCF_V3_BRAIN \
  --nexus-id $NEXUS_ID_ANNOTATION_VOLUME_MOUSE_CCF_V3_BRAIN \
  --verbose

# Fetching Mouse CCF v3 average template volume
echo "📥 Fetching brain average template volume..."
bba-data-fetch --nexus-env $NEXUS_ATLAS_ENV \
  --nexus-token $ACCESS_TOKEN \
  --nexus-org $NEXUS_ATLAS_ORG \
  --nexus-proj $NEXUS_ATLAS_PROJ \
  --out $FETCHED_TEMPLATE_VOLUME_MOUSE_CCF_V3 \
  --nexus-id $NEXUS_ID_TEMPLATE_VOLUME_MOUSE_CCF_V3 \
  --verbose 


# Fetching Mouse CCF ontology (1.json)
echo "📥 Fetching brain region ontology..."
bba-data-fetch --nexus-env $NEXUS_ATLAS_ENV \
  --nexus-token $ACCESS_TOKEN \
  --nexus-org $NEXUS_ONTOLOGY_ORG \
  --nexus-proj $NEXUS_ONTOLOGY_PROJ \
  --out $FETCHED_ONTOLOGY_MOUSE_CCF \
  --nexus-id $NEXUS_ID_ONTOLOGY_MOUSE_CCF \
  --favor name:1.json \
  --verbose


# Computing the direction vector volume
echo "🤖 Computing direction vectors for isocortex..."
atlas-building-tools direction-vectors isocortex --annotation-path $FETCHED_ANNOTATION_VOLUME_MOUSE_CCF_V3_BRAIN \
  --hierarchy-path $FETCHED_ONTOLOGY_MOUSE_CCF \
  --output-path $COMPUTED_VOLUME_DIRECTION_VECTOR_ISOCORTEX


# echo "🤖 Computing orientation fields for isocortex..."
atlas-building-tools orientation-field  --direction-vectors-path $COMPUTED_VOLUME_DIRECTION_VECTOR_ISOCORTEX \
  --output-path $COMPUTED_VOLUME_ORIENTATION_FIELD_ISOCORTEX


# echo "🤖 Computing splitting L2/L3 from isocortex..."
atlas-building-tools region-splitter split-isocortex-layer-23 --hierarchy-path $FETCHED_ONTOLOGY_MOUSE_CCF \
  --annotation-path $FETCHED_ANNOTATION_VOLUME_MOUSE_CCF_V3_BRAIN \
  --direction-vectors-path $COMPUTED_VOLUME_DIRECTION_VECTOR_ISOCORTEX \
  --output-hierarchy-path $COMPUTED_ONTOLOGY_MOUSE_CCF_SPLIT_L2L3 \
  --output-annotation-path $COMPUTED_ANNOTATION_VOLUME_MOUSE_CCF_V3_BRAIN_SPLIT_L2L3


# echo "🤖 Computing placement hints..."
mkdir -p $COMPUTED_PLACEMENT_HINTS_DIR
atlas-building-tools placement-hints isocortex --annotation-path $COMPUTED_ANNOTATION_VOLUME_MOUSE_CCF_V3_BRAIN_SPLIT_L2L3 \
  --hierarchy-path $COMPUTED_ONTOLOGY_MOUSE_CCF_SPLIT_L2L3 \
  --direction-vectors-path $COMPUTED_VOLUME_DIRECTION_VECTOR_ISOCORTEX \
  --output-dir $COMPUTED_PLACEMENT_HINTS_DIR \
  --algorithm voxel-based


# echo "🤖 Computing region meshes and masks..."
mkdir -p $COMPUTED_ANNOTATION_MESHES_DIR
mkdir -p $COMPUTED_ANNOTATION_MASKS_DIR
parcellationexport --hierarchy $COMPUTED_ONTOLOGY_MOUSE_CCF_SPLIT_L2L3 \
  --parcellation-volume $COMPUTED_ANNOTATION_VOLUME_MOUSE_CCF_V3_BRAIN_SPLIT_L2L3 \
  --out-mesh-dir $COMPUTED_ANNOTATION_MESHES_DIR \
  --out-mask-dir $COMPUTED_ANNOTATION_MASKS_DIR \
  --out-metadata $COMPUTED_REGIONS_METADATA \
  --out-hierarchy-jsonld $COMPUTED_ONTOLOGY_MOUSE_CCF_SPLIT_L2L3_JSONLD

