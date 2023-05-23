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

echo "Load the singularity module:"
module load unstable
module use /gpfs/bbp.cscs.ch/apps/hpc/singularity/modules/linux-rhel7-x86_64
module load singularityce

echo "Check if singularity is found:"
singularity --version

echo "We use a cache directory in ${TMPDIR} which is on local NVME"
mkdir -p ${TMPDIR}/singularity-cachedir
export SINGULARITY_CACHEDIR=${TMPDIR}/singularity-cachedir
export SINGULARITY_DOCKER_USERNAME=${CI_REGISTRY_USER}
export SINGULARITY_DOCKER_PASSWORD=${CI_JOB_TOKEN}
echo "Pulling the image from the GitLab registry:"
image="${CI_PROJECT_NAME}_${REGISTRY_IMAGE_TAG}"
imagesif="$image.sif"
tmpimage="${TMPDIR}/$imagesif"
singularity pull --no-https $tmpimage docker://$CI_REGISTRY_IMAGE:$REGISTRY_IMAGE_TAG

echo "At this stage, we have the singularity image at $tmpimage"
ls -la $tmpimage

#echo "Run tests: as a demo, just check if we can get the help of 2048"
#singularity exec --containall ${TMPDIR}/blue_brain_atlas_pipeline.sif 2048 -h

echo "Deploying the image to proj83"
export GPFSDIR=/gpfs/bbp.cscs.ch/data/project/proj83/singularity-images
export NAME_WITH_TIMESTAMP=$image-$(date +%Y-%m-%dT%H:%M:%S).sif
mkdir -p ${GPFSDIR}
mv $tmpimage ${GPFSDIR}/${NAME_WITH_TIMESTAMP}
imagepath="${GPFSDIR}/$imagesif"
# rm the previous link
rm -f $imagepath
ln -s ${GPFSDIR}/${NAME_WITH_TIMESTAMP} $imagepath

echo "Updated $imagepath which is actually a symbolic link to ${GPFSDIR}/${NAME_WITH_TIMESTAMP}"

