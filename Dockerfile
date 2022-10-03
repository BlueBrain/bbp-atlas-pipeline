FROM ubuntu:focal

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

RUN apt-get -y install pip git

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
RUN pip install git+https://gitlab-ci-token:${CI_JOB_TOKEN}@bbpgitlab.epfl.ch/dke/apps/blue_brain_nexus_token_fetch.git@v0.2.0

# module load py-bba-datafetch
RUN pip install git+https://gitlab-ci-token:${CI_JOB_TOKEN}@bbpgitlab.epfl.ch/dke/apps/blue_brain_atlas_data_fetch.git@v0.1.0

# module load py-bba-webexporter
RUN pip install git+https://gitlab-ci-token:${CI_JOB_TOKEN}@bbpgitlab.epfl.ch/dke/apps/blue_brain_atlas_web_exporter.git@v0.1.5

# module load py-data-integrity-check
RUN pip install git+https://gitlab-ci-token:${CI_JOB_TOKEN}@bbpgitlab.epfl.ch/dke/apps/blue_brain_atlas_data_integrity_check.git@v0.1.0

RUN pip install git+https://gitlab-ci-token:${CI_JOB_TOKEN}@bbpgitlab.epfl.ch/dke/apps/blue_brain_nexus_push.git@v0.1.0

RUN git config --global --remove-section url."https://gitlab-ci-token:${CI_JOB_TOKEN}@bbpgitlab.epfl.ch/"

# module load py-atlas-building-tools
RUN pip install -i https://bbpteam.epfl.ch/repository/devpi/simple/ atlas-building-tools==0.1.9

RUN pip install snakemake==7.12.1

RUN CA_BUNDLE=$(python3 -c "import certifi; print(certifi.where())")
RUN cat $BBP_CA_CERT >> $CA_BUNDLE

