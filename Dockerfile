FROM python:3.9-slim

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

COPY .. blue_brain_atlas_pipeline/

# Regiodesics
#RUN git clone https://bbpgitlab.epfl.ch/nse/archive/regiodesics  && \
#	cd regiodesics  &&  git submodule update --init  && \
#	mkdir build  &&  cd build  && \
#	cmake ..  &&  make -j  &&  cd ..  && \
#	export PATH=$PATH:$PWD/build/bin

# For install dependencies
RUN git config --global --add url."https://gitlab-ci-token:${CI_JOB_TOKEN}@bbpgitlab.epfl.ch/".insteadOf https://bbpgitlab.epfl.ch/

# module load py-token-fetch
RUN pip install git+https://bbpgitlab.epfl.ch/dke/apps/blue_brain_nexus_token_fetch.git@v0.2.0

# module load py-bba-datafetch
RUN pip install git+https://bbpgitlab.epfl.ch/dke/apps/blue_brain_atlas_data_fetch.git@v0.1.0

# module load py-bba-webexporter
RUN pip install git+https://bbpgitlab.epfl.ch/dke/apps/blue_brain_atlas_web_exporter.git@v0.1.5

# module load py-data-integrity-check
RUN pip install git+https://bbpgitlab.epfl.ch/dke/apps/blue_brain_atlas_data_integrity_check.git@v0.1.0

RUN pip install git+https://bbpgitlab.epfl.ch/dke/apps/blue_brain_nexus_push.git@densities

RUN pip install -i https://bbpteam.epfl.ch/repository/devpi/simple/ git+https://bbpgitlab.epfl.ch/nse/cwl-registry.git@separate-funcs

RUN pip install git+https://bbpgitlab.epfl.ch/dke/users/jonathanlurie/atlas_cell_transplant.git@develop

RUN git config --global --remove-section url."https://gitlab-ci-token:${CI_JOB_TOKEN}@bbpgitlab.epfl.ch/"

# Need the latest atlas-commons branch until v0.1.5 is shipped along with atlas-building-tools below
RUN pip install git+https://github.com/BlueBrain/atlas-commons@main

# Need the latest atlas-densities branch until v0.1.4 is shipped along with atlas-building-tools below
RUN pip install git+https://github.com/BlueBrain/atlas-densities@main

# module load py-atlas-building-tools
RUN pip install -i https://bbpteam.epfl.ch/repository/devpi/simple/ atlas-building-tools>=0.1.9

RUN pip install snakemake>=7.20.0

RUN CA_BUNDLE=$(python3 -c "import certifi; print(certifi.where())"); ls $CA_BUNDLE; echo "BBP_CA_CERT: $BBP_CA_CERT"; echo "$BBP_CA_CERT" >> $CA_BUNDLE ; export SSL_CERT_FILE=$CA_BUNDLE
