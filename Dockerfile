FROM python:3.10-slim

ARG CI_JOB_TOKEN
ARG BBP_CA_CERT

RUN apt-get update && \
        DEBIAN_FRONTEND="noninteractive" TZ="Europe/Zurich" apt-get install -y tzdata && \
        apt-get install -y --no-install-recommends \
        build-essential \
        ninja-build \
        cmake \
        libboost-filesystem-dev \
        libboost-program-options-dev \
        libopenscenegraph-dev

RUN apt-get -y install pip git vim

WORKDIR /pipeline

COPY .. .

# Regiodesics
#RUN git clone https://bbpgitlab.epfl.ch/nse/archive/regiodesics  && \
#	cd regiodesics  &&  git submodule update --init  && \
#	mkdir build  &&  cd build  && \
#	cmake ..  &&  make -j  &&  cd ..  && \
#	export PATH=$PATH:$PWD/build/bin

# Install the pipeline repository (along with the bbp-atlas CLI)
RUN pip install blue_brain_atlas_pipeline/

# For install dependencies
RUN git config --global --add url."https://gitlab-ci-token:${CI_JOB_TOKEN}@bbpgitlab.epfl.ch/".insteadOf https://bbpgitlab.epfl.ch/

# module load py-token-fetch
RUN pip install git+https://bbpgitlab.epfl.ch/dke/apps/blue_brain_nexus_token_fetch.git@v0.2.0

# module load py-bba-datafetch
RUN pip install git+https://bbpgitlab.epfl.ch/dke/apps/blue_brain_atlas_data_fetch.git@v0.2.2

# temporary test, will be ported into atlas-splitter
#RUN pip install git+https://bbpgitlab.epfl.ch/conn/structural/validation/cell-density-validations/cell-densities.git@2325c56d
RUN git clone --branch new_regions_hier https://bbpgitlab.epfl.ch/conn/structural/validation/cell-density-validations.git cell-density-validation
RUN cd cell-density-validation  &&  git checkout 94c2f3aa  &&  pip install cell-densities/

# module load py-bba-webexporter
RUN pip install git+https://bbpgitlab.epfl.ch/dke/apps/blue_brain_atlas_web_exporter.git@v2.0.3

# module load py-data-integrity-check
RUN pip install git+https://bbpgitlab.epfl.ch/dke/apps/blue_brain_atlas_data_integrity_check.git@v0.1.0

# cwl-registry depends on blue_brain_nexus_push so it must be installed first to not overwrite the blue_brain_nexus_push version
RUN pip install -i https://bbpteam.epfl.ch/repository/devpi/simple/ git+https://bbpgitlab.epfl.ch/nse/cwl-registry.git@cwl-registry-v0.4.3

# module load py-bba-data-push
RUN pip install git+https://bbpgitlab.epfl.ch/dke/apps/blue_brain_nexus_push.git@6d959477

RUN pip install git+https://bbpgitlab.epfl.ch/dke/users/jonathanlurie/atlas_cell_transplant.git@v0.2.0

RUN pip install git+https://bbpgitlab.epfl.ch/dke/apps/pipeline-validator.git@0.1.1

RUN git config --global --remove-section url."https://gitlab-ci-token:${CI_JOB_TOKEN}@bbpgitlab.epfl.ch/"

# Need the latest atlas-commons branch until v0.1.5 is cut
RUN pip install git+https://github.com/BlueBrain/atlas-commons@b083081

RUN pip install git+https://github.com/BlueBrain/atlas-splitter@v0.1.2

RUN pip install git+https://github.com/Sebastien-PILUSO/atlas-densities@ea9b789

# module load py-atlas-building-tools
RUN pip install -i https://bbpteam.epfl.ch/repository/devpi/simple/ "atlas-building-tools==0.1.10"

RUN pip install "snakemake==7.32.3"
