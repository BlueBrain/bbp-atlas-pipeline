FROM ubuntu:focal

ARG GITLAB_DEPLOY_TOKEN
ARG GITLAB_DEPLOY_PASSWORD
ARG CI_DEPLOY_TOKEN
ARG CI_DEPLOY_PASSWORD
ARG CI_JOB_TOKEN
RUN echo "GITLAB_DEPLOY_TOKEN: $GITLAB_DEPLOY_TOKEN" and "GITLAB_DEPLOY_PASSWORD: $GITLAB_DEPLOY_PASSWORD"
RUN echo "CI_DEPLOY_TOKEN: $CI_DEPLOY_TOKEN" and "CI_DEPLOY_PASSWORD: $CI_DEPLOY_PASSWORD"
RUN echo "CI_JOB_TOKEN": $CI_JOB_TOKEN

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

WORKDIR /annotation

# Regiodesics
#RUN git clone https://bbpgitlab.epfl.ch/nse/archive/regiodesics  && \
#	cd regiodesics  &&  git submodule update --init  && \
#	mkdir build  &&  cd build  && \
#	cmake ..  &&  make -j  &&  cd ..  && \
#	export PATH=$PATH:$PWD/build/bin

# test
RUN git clone https://$GITLAB_DEPLOY_TOKEN:$GITLAB_DEPLOY_PASSWORD@bbpgitlab.epfl.ch/dke/apps/blue_brain_atlas_pipeline.git deploy_token
RUN git clone https://gitlab-ci-token:${CI_JOB_TOKEN}@bbpgitlab.epfl.ch/dke/apps/blue_brain_atlas_pipeline.git job_token

# module load py-token-fetch
RUN pip install git+https://gitlab-ci-token:${CI_JOB_TOKEN}@bbpgitlab.epfl.ch/dke/apps/blue_brain_nexus_token_fetch.git@develop

# module load py-bba-datafetch
RUN pip install git+https://gitlab-ci-token:${CI_JOB_TOKEN}@bbpgitlab.epfl.ch/dke/apps/blue_brain_atlas_data_fetch.git

# module load py-bba-webexporter
RUN pip install git+https://gitlab-ci-token:${CI_JOB_TOKEN}@bbpgitlab.epfl.ch/dke/apps/blue_brain_atlas_web_exporter.git

# module load py-data-integrity-check
RUN pip install git+https://gitlab-ci-token:${CI_JOB_TOKEN}@bbpgitlab.epfl.ch/dke/apps/blue_brain_atlas_data_integrity_check.git

RUN pip install git+https://gitlab-ci-token:${CI_JOB_TOKEN}@bbpgitlab.epfl.ch/dke/apps/blue_brain_nexus_push.git@develop

# module load py-atlas-building-tools
RUN pip install -i https://bbpteam.epfl.ch/repository/devpi/simple/ atlas-building-tools

RUN pip install snakemake
