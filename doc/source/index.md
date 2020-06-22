# Blue Brain Atlas Pipeline
> ℹ️ The complete documentation for the Atlas Pipeline is on [Confluence](https://bbpteam.epfl.ch/project/spaces/display/BBKG/Atlas+Pipeline).



The Atlas Pipeline is a set of processing modules that generate new data such as:
- Aligned datasets from unaligned gene expression slices
- A hybrid annotation volume based on Allen Mouse CCF. This includes:
- Information from CCFv2 and CCFv3
- Split of layer 2 and 3
- Cell density volumes for several cell types
- Volumes representing cortical and layer depth of Isocortex
- Cell positions

Historically, the first mission of this pipeline was to generate cell density volumes as well as point cloud datasets with individual cell positions and cell type. As the pipeline was gaining interest and contributors, its scope has broadened, hence the decision to have a more modular approach in terms of software architecture.

Now, the goal of this pipeline is to generate some key reference datasets for The Blue Brain Projects to be used by BBP researchers and engineers. This can be made possible only if some strict rules are respected, among them:

Each module of the pipeline must be independent, with a limited scope that does not overlap on the scope of other modules
- Each module must be documented and maintained by a domain expert
- The code of each module must be versioned (git)
- Alongside the generated datasets must be recorded which modules and which versions of these modules was used, as well as which input data
- The generated datasets must be pushed into a trustable platform, where versioning, provenance, rich metadata and integrity check are the norm
- The datasets produced by this pipeline must be made available to everyone at BBP who may need it, with simple tools

# Atlas Modules
The pipeline is composed of independent modules that are developed by different people and team with the relevant expertise for each.

Python is a popular language for the development of the modules but the only requirement is that a module exposes an executable CLI, the language actually does not matter too much. You can find more information about the good practice for module development on [Confluence](https://bbpteam.epfl.ch/project/spaces/display/BBKG/Modules).

# File formats and standards
The engineers of the Blue Brain Atlas Pipeline and its modules are trying there best to use standard when this is possible. When it is not, we will do our best to provide all the resources necessary to understand, read and create datasets in a specific/in-house formats. Read more about it on [Confluence](https://bbpteam.epfl.ch/project/spaces/display/BBKG/File+formats%2C+data+structure).

## NRRD Volumetric files
The NRRD file format is widely used in the neuroinformatics community and became a standard at BBP. The original specifications allows a lot of optional properties, though some of them provide valuable informations and hence are being enforced at BBP. Read the full section on [Confluence](https://bbpteam.epfl.ch/project/spaces/display/BBKG/BBP+NRRD).

# Data
A faire share of the data used in the Atlas Pipeline originally comes from the Allen Brain Institute for Brain Science (AIBS). On of the issue of relying on AIBS API is the lack of versioning, thus the lack of traceability that could result in disparities in the results of the pipeline.  
To guaranty provenance and traceability, all the input dataset of the pipeline are being stored in the Blue Brain Knowledge Graph (Nexus).  
Read more about the *Allen Mouse CCF data in Nexus* on [Confluence](https://bbpteam.epfl.ch/project/spaces/display/BBKG/Allen+Mouse+CCF+Compatible+Data).