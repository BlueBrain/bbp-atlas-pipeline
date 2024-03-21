set -x
set -e

echo "Running on BB5 as the following user:"
id

echo "Current working directory:"
pwd

echo "Running on the following node:"
hostname

echo "TMPDIR, which should be on local NVME because we asked for a node with local storage:"
echo $TMPDIR

echo "Check if singularity is found:"
singularity --version

echo "We use a cache directory in ${TMPDIR} which is on local NVME"
singularity_cachedir=${TMPDIR}/singularity-cachedir
mkdir -p ${singularity_cachedir}
export SINGULARITY_CACHEDIR=${singularity_cachedir}
export SINGULARITY_DOCKER_USERNAME=${CI_REGISTRY_USER}
export SINGULARITY_DOCKER_PASSWORD=${CI_JOB_TOKEN}
echo "Pulling the image from the GitLab registry:"
tmpimage="${TMPDIR}/${IMAGE_LINK}"
singularity pull --no-https $tmpimage docker://$CI_REGISTRY_IMAGE:$REGISTRY_IMAGE_TAG

echo "At this stage, we have the singularity image at $tmpimage"
ls -la $tmpimage

#echo "Run tests: as a demo, just check if we can get the help of 2048"
#singularity exec --containall ${TMPDIR}/blue_brain_atlas_pipeline.sif 2048 -h

echo "Deploying the image to proj84"
mkdir -p ${IMAGES_DIR}
mv $tmpimage $IMAGE_PATH
# remove the previous link
rm -f ${IMAGE_LINK_PATH}
ln -s $IMAGE_PATH $IMAGE_LINK_PATH

echo "Updated ${IMAGE_LINK_PATH} which is actually a symbolic link to ${IMAGE_PATH}"
