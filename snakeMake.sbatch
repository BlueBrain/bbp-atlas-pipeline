#!/bin/bash -l
#SBATCH -N 1			# Number of nodes

#SBATCH -p prod		# Submit to the production 'partition'
##SBATCH -t 24:00:00		# Set 24 hours time limit

#SBATCH --qos=longjob		# Allows to run a job up to 3 days
#SBATCH -t 72:00:00		# Set 24 hours time limit

#SBATCH -C "knl"		# Constraint the job to run on nodes without SSDs. If you want SSD, use only "nvme". If you want KNLs then "knl"
#SBATCH --exclusive		# only if you want to allocate whole node
##SBATCH --ntasks-per-node=64	# no of mpi ranks to use per node. 36 for cpu, 64 for KNLs [Deprecated]

#SBATCH --account=proj83	# your project number
#SBATCH --mem=0			# make sure entire memory is allocated to the job

FILE=snakefile
#FILE=snakefile_noMaskMesh

#TARGET=generate_annotation_pipeline_datasets
#TARGET=push_annotation_pipeline_datasets
#TARGET=create_mtypes_densities_from_probability_map_ccfv2_l23split_correctednissl
TARGET=push_celldensity_transplant_l23split_pipeline_datasets

module load unstable

# for bba-data-push
module load python/3.9.7 
python -m venv ../venv/
source ../venv/bin/activate

# Package not available on BB5
pip install ../blue_brain_nexus_push/

module load py-token-fetch
module load py-bba-datafetch
module load py-atlas-building-tools
#module load py-data-integrity-check # BB5 version is outdated
pip install ../blue_brain_atlas_data_integrity_check
module load py-nexusforge
module load py-bba-webexporter
module load snakemake

snakemake --unlock -s $FILE $TARGET
snakemake --rerun-incomplete -s $FILE $TARGET
