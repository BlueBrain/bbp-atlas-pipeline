FROM python:3.10-slim

ARG REF_NAME=main  # Default to 'main' if REF_NAME is not passed

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
RUN pip install git+https://github.com/BlueBrain/bbp-atlas-pipeline.git@${REF_NAME}

# Install dependencies

# module load py-token-fetch
RUN pip install "blue-brain-token-fetch>=1.0.0"

# module load py-bba-datafetch
RUN pip install git+https://github.com/BlueBrain/bbp-atlas-data-fetch.git@v0.3.0

# densities validation
RUN pip install git+https://github.com/BlueBrain/molsys-cell-atlas.git@v1.0.0

# leaves-only
RUN pip install git+https://github.com/BlueBrain/cell-density-validations.git@v0.2.1

# module load py-bba-webexporter
RUN pip install git+https://github.com/BlueBrain/bbp-atlas-web-exporter.git@v3.0.0

RUN pip install blue-cwl

# module load py-bba-data-push
RUN pip install "blue-brain-data-push>=4.3.0"

RUN pip install "bbp-atlas-pipeline-validator>=0.3.1"

RUN pip install "atlas-commons>=0.1.5"

RUN pip install "atlas-direction-vectors"

RUN pip install "atlas-splitter>=0.1.5"

RUN pip install "atlas-placement-hints>=0.1.4"

RUN pip install "atlas-densities>=0.2.5"

RUN pip install "snakemake==7.32.3"
