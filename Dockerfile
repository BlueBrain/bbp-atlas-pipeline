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
RUN pip install -i https://bbpteam.epfl.ch/repository/devpi/simple/ blue_brain_atlas_pipeline/

# For install dependencies
RUN git config --global --add url."https://gitlab-ci-token:${CI_JOB_TOKEN}@bbpgitlab.epfl.ch/".insteadOf https://bbpgitlab.epfl.ch/

# module load py-token-fetch
RUN pip install -i https://bbpteam.epfl.ch/repository/devpi/simple/ "blue-brain-token-fetch>=1.0.0"

# module load py-bba-datafetch
RUN pip install -i https://bbpteam.epfl.ch/repository/devpi/simple/ "bba-data-fetch>=0.3.0"

# densities validation
RUN pip install -i https://bbpteam.epfl.ch/repository/devpi/simple/ "densities-validation>=0.1.1"

# leaves-only
RUN pip install -i https://bbpteam.epfl.ch/repository/devpi/simple/ "cell-densities>=0.2.1"

# module load py-bba-webexporter
RUN pip install -i https://bbpteam.epfl.ch/repository/devpi/simple/ "blue-brain-atlas-web-exporter>=3.0.0"

# module load py-data-integrity-check
RUN pip install -i https://bbpteam.epfl.ch/repository/devpi/simple/ "bba-data-integrity-check>=0.2.0"

RUN pip install blue-cwl

# module load py-bba-data-push
RUN pip install -i https://bbpteam.epfl.ch/repository/devpi/simple/ "bba-data-push>=4.2.0"

RUN pip install git+https://bbpgitlab.epfl.ch/dke/users/jonathanlurie/atlas_cell_transplant.git@v0.3.1

RUN pip install -i https://bbpteam.epfl.ch/repository/devpi/simple/ "pipeline-validator>=0.3.1"

RUN git config --global --remove-section url."https://gitlab-ci-token:${CI_JOB_TOKEN}@bbpgitlab.epfl.ch/"

RUN pip install "atlas-commons>=0.1.5"

RUN pip install "atlas-direction-vectors"

RUN pip install "atlas-splitter>=0.1.5"

RUN pip install "atlas-placement-hints"

RUN pip install "atlas-densities>=0.2.5"

RUN pip install "snakemake==7.32.3"
