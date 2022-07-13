'''
In the following, the term "preparing" means we locally initialize the resource,
including the creation of its ID, so that other resource can already establish a
link to it before it is even pushed.

Event should happen in this order:
- Preparing the new brain region ontology
- Preparing the new AtlasRelease locally
- Preparing the new annotation volume
- Preparing the (not really) new brain template volume

'''

import uuid
import argparse
from kgforge.core import KnowledgeGraphForge
from kgforge.core import Resource
import sys
import json
import os
import numpy as np
import nrrd
from datetime import datetime
import blue_brain_atlas_web_exporter.TreeIndexer as TreeIndexer



NRRD_TYPES_TO_NUMPY = {
    "signed char": "int8",
    "int8": "int8",
    "int8_t": "int8",
    "uchar": "uint8",
    "unsigned char": "uint8",
    "uint8": "uint8",
    "uint8_t": "uint8",
    "short": "int16",
    "short int": "int16",
    "signed short": "int16",
    "signed short int": "int16",
    "int16": "int16",
    "int16_t": "int16",
    "ushort": "int16",
    "unsigned short": "uint16",
    "unsigned short int": "uint16",
    "uint16": "uint16",
    "uint16_t": "uint16",
    "int": "int32",
    "signed int": "int32",
    "int32": "int32",
    "int32_t": "int32",
    "uint": "uint32",
    "unsigned int": "uint32",
    "uint32": "uint32",
    "uint32_t": "uint32",
    "longlong": "int64",
    "long long": "int64",
    "long long int": "int64",
    "signed long long": "int64",
    "signed long long int": "int64",
    "int64": "int64",
    "int64_t": "int64",
    "ulonglong": "uint64",
    "unsigned long long": "uint64",
    "unsigned long long int": "uint64",
    "uint64": "uint64",
    "uint64_t": "uint64",
    "float": "float32",
    "double": "float64"
}


dataSampleModalities = {
  "PARCELLATION_ID": "parcellationId",
  "CELL_TYPE_ID": "cellTypeId",
  "COLOR_RGB": "colorRGB",
  "COLOR_RGBA": "colorRGBA",
  "EULER_ANGLE": "eulerAngle",
  "GRADIENT_2D": "gradient2D",
  "GRADIENT_3D": "gradient3D",
  "LUMINANCE": "luminance",
  "MARKER_INTENSITY": "markerIntensity",
  "MASK": "mask",
  "POSITION_2D": "position2D",
  "POSITION_3D": "position3D",
  "QUANTITY": "quantity",
  "QUATERNION": "quaternion",
}

dataSampleModalitiesNumberOfComponents = {
  "PARCELLATION_ID": 1,
  "CELL_TYPE_ID": 1,
  "COLOR_RGB": 3,
  "COLOR_RGBA": 4,
  "EULER_ANGLE": 3,
  "GRADIENT_2D": 2,
  "GRADIENT_3D": 3,
  "LUMINANCE": 1,
  "MARKER_INTENSITY": 1,
  "MASK": 1,
  "POSITION_2D": 2,
  "POSITION_3D": 3,
  "QUANTITY": 1,
  "QUATERNION": 4,
}

VOLUMETRICDATALAYER_SCHEMAS_ID = "https://neuroshapes.org/dash/volumetricdatalayer"
ONTOLOGY_SCHEMAS_ID = "https://neuroshapes.org/dash/ontology"
ATLASRELEASE_SCHEMAS_ID = "https://neuroshapes.org/dash/atlasrelease"

def generate_payload_volumetric_data_layer(filepath, id, name, description, type, atlas_release_id, srs_id, region_node, sample_modality, resolution):
    
    nrrd_header = nrrd.read_header(filepath)
    return {
        "@id": id,
        "@type": [
            "VolumetricDataLayer",
            type,
            "Dataset"
        ],
        "atlasRelease": {
            "@id": atlas_release_id
        },
        "brainLocation": {
            "atlasSpatialReferenceSystem": {
            "@id": srs_id,
            "@type": [
                "AtlasSpatialReferenceSystem",
                "BrainAtlasSpatialReferenceSystem"
            ]
            },
            "brainRegion": {
            "@id": f"mba:{region_node['id']}",
            "label": region_node["name"],
            }
        },
        
        "bufferEncoding": nrrd_header["encoding"],

        "componentEncoding": NRRD_TYPES_TO_NUMPY[nrrd_header["type"]],

        "contribution": {
            "@type": "Contribution",
            "agent": {
            "@id": "https://ror.org/02s376052",
            "@type": [
                "Organization",
                "Agent"
            ]
            }
        },

        "dataSampleModality": dataSampleModalities[sample_modality],

        "description": description,
        "dimension": [
            {
            "@type": "ComponentDimension",
            "name": dataSampleModalities[sample_modality],
            "size": dataSampleModalitiesNumberOfComponents[sample_modality],
            },
            {
            "@type": "SpaceDimension",
            "size": 528,
            "unitCode": "voxel"
            },
            {
            "@type": "SpaceDimension",
            "size": 320,
            "unitCode": "voxel"
            },
            {
            "@type": "SpaceDimension",
            "size": 456,
            "unitCode": "voxel"
            }
        ],
   
        "endianness": nrrd_header.get("endian", "little"),

        "fileExtension": "nrrd",
        "isRegisteredIn": {
            "@id": srs_id,
            "@type": [
            "AtlasSpatialReferenceSystem",
            "BrainAtlasSpatialReferenceSystem"
            ]
        },
        "name": name,
        "resolution": {
            "unitCode": "µm",
            "value": resolution
        },
        "sampleType": "label",
        "subject": {
            "@type": "Subject",
            "species": {
            "@id": "http://purl.obolibrary.org/obo/NCBITaxon_10090",
            "label": "Mus musculus"
            }
        },
        "worldMatrix": [
            resolution,
            0,
            0,
            0,
            0,
            resolution,
            0,
            0,
            0,
            0,
            resolution,
            0,
            0,
            0,
            0,
            1
        ]
        }


def generate_payload_region_mesh(filepath, id, name, description, atlas_release_id, srs_id, region_id,):
    return {
        "@type": [
            "Mesh",
            "BrainParcellationMesh"
        ],
        "atlasRelease": {
            "@id": atlas_release_id
        },
        "brainLocation": {
            "atlasSpatialReferenceSystem": {
                "@id": srs_id,
                "@type": [
                    "AtlasSpatialReferenceSystem",
                    "BrainAtlasSpatialReferenceSystem"
                ]
          },
          "brainRegion": {
              "@id": f"mba:{region_id}",
          }
        },
        "description": description,
        "isRegisteredIn": {
            "@id": srs_id,
            "@type": [
                "BrainAtlasSpatialReferenceSystem",
                "AtlasSpatialReferenceSystem"
            ]
        },
        "name": name,
        "spatialUnit": "µm",
        "subject": {
            "@type": "Subject",
            "species": {
                "@id": "http://purl.obolibrary.org/obo/NCBITaxon_10090",
                "label": "Mus musculus"
            }
        }
    }


def generate_payload_brain_region_ontology(id, name):
    return {
      "@id": id,
      "@type": [
        "Ontology",
        "Entity",
        "ParcellationOntology"
      ],
      "label": name,
      "name": name,
      "wasDerivedFrom": {
        "@id": "http://ontology.neuinfo.org/NIF/ttl/generated/parcellation/mbaslim.ttl"
      }
    }


def generate_payload_atlas_release(atlas_release_id, name, description, brain_template_id, brain_region_ontology_id, parcellation_volume_id, srs_id):
    return {
        "@id": atlas_release_id,
        "@type": [
            "AtlasRelease",
            "BrainAtlasRelease"
        ],
        "brainTemplateDataLayer": {
            "@id": brain_template_id,
            "@type": "BrainTemplateDataLayer"
        },
        "description": description,
        "name": name,
        "parcellationOntology": {
            "@id": brain_region_ontology_id,
            "@type": "ParcellationOntology"
        },
        "parcellationVolume": {
            "@id": parcellation_volume_id,
            "@type": "BrainParcellationDataLayer"
        },
        "releaseDate": {
            "@type": "xsd:date",
            "@value": datetime.today().strftime("%Y-%m-%d")
        },
        "spatialReferenceSystem": {
            "@id": srs_id,
            "@type": "AtlasSpatialReferenceSystem"
        },
        "subject": {
            "@type": "Subject",
            "species": {
                "@id": "http://purl.obolibrary.org/obo/NCBITaxon_10090",
                "label": "Mus musculus"
            }
        }
    }


def parse_args():
    parser = argparse.ArgumentParser()

    parser.add_argument(
        "--forge-config",
        dest="forge_config",
        required=True,
        metavar="<FILE PATH>",
        help="The path to the Nexus Forge configuration file")

    parser.add_argument(
        "--nexus-env",
        dest="nexus_env",
        required=True,
        metavar="<URL>",
        help="URL to the Nexus environment")

    parser.add_argument(
        "--nexus-org",
        dest="nexus_org",
        required=True,
        metavar="<NAME>",
        help="Name of the Nexus organization to push data to")

    parser.add_argument(
        "--nexus-proj",
        dest="nexus_proj",
        required=True,
        metavar="<NAME>",
        help="Name of the Nexus project to push data to")

    parser.add_argument(
        "--access-token",
        dest="access_token",
        required=True,
        metavar="<NAME>",
        help="Access token (JWT) to push data to Nexus")
        
    parser.add_argument(
        "--nexus-id-aibs-ccf-srs",
        dest="nexus_id_aibs_ccf_srs",
        required=True,
        metavar="<NEXUS ID>",
        help="Nexus ID of the Spatial Reference System")

    parser.add_argument(
        "--hierarchy",
        dest="hierarchy",
        required=True,
        metavar="<FILE PATH>",
        help="The hierarchy JSON file, sometimes called 1.json")

    parser.add_argument(
        "--hierarchy-ld",
        dest="hierarchy_ld",
        required=True,
        metavar="<FILE PATH>",
        help="The hierarchy in JSON-LD format")

    parser.add_argument(
        "--annotation-volume",
        dest="annotation_volume",
        required=True,
        metavar="<FILE PATH>",
        help="The NRRD brain region annotation volume")

    parser.add_argument(
        "--template-volume",
        dest="template_volume",
        required=True,
        metavar="<FILE PATH>",
        help="The NRRD brain template volume")

    parser.add_argument(
        "--out-atlasrelease-id-file",
        dest="out_atlasrelease_id_file",
        required=False,
        metavar="<FILE PATH>",
        help="The file to write the ID of the newly created AtlasRelease Nexus Resource")

    return parser.parse_args()



def main():
    args = parse_args()

    forge = KnowledgeGraphForge(
        args.forge_config,
        endpoint=args.nexus_env,
        bucket=f"{args.nexus_org}/{args.nexus_proj}",
        token=args.access_token,
        debug=True,
    )

    forge._debug=True

    # Predefining the @ids of the AtlaRelease and the items being pointed at by the AtlasRelease
    atlas_release_id = forge.format("identifier", str(uuid.uuid4()))
    brain_ontology_id = forge.format("identifier", str(uuid.uuid4()))
    brain_annotation_volume_id = forge.format("identifier", str(uuid.uuid4()))
    brain_template_volume_id = forge.format("identifier", str(uuid.uuid4()))
    srs_id = args.nexus_id_aibs_ccf_srs

    print("ID of atlas release to push: ", atlas_release_id)
    print("ID of brain region ontology to push: ", brain_ontology_id)
    print("ID of annotation volume to push: ", brain_annotation_volume_id)
    print("ID of template volume to push: ", brain_template_volume_id)
    print("Using SRS: ", srs_id)

    # Reading the brain region ontology, to later being able to generate
    # better names that include brain region labels
    brain_onto_json = json.loads(open(args.hierarchy, "r").read())
    # sometimes, the 1.json has its content in a "msg" sub prop (the original version has).
    # and some other versions don't. Here we deal with both
    if "msg" in brain_onto_json:
        onto_flat_tree = TreeIndexer.flattenTree(brain_onto_json['msg'][0])
    else:
        onto_flat_tree = TreeIndexer.flattenTree(brain_onto_json)

    # finding the root node of the brain region ontology
    root_node = None
    for node_id in onto_flat_tree:
        node = onto_flat_tree[node_id]
        if len(node["_ascendants"]) == 0:
            root_node = node
            break

    # Generating the base payload for the brain region ontology
    print("Pushing to Nexus: Brain region ontology...")
    brain_ontology_payload = generate_payload_brain_region_ontology(
        brain_ontology_id,
        "BBP Mouse Brain region ontology",
    )
    nexus_distrib_hierarchy = forge.attach(args.hierarchy, content_type="application/json")
    nexus_distrib_hierarchy_ld = forge.attach(args.hierarchy_ld, content_type="application/ld+json")
    nexus_resource_hierarchy = Resource.from_json(brain_ontology_payload)
    nexus_resource_hierarchy.distribution = [nexus_distrib_hierarchy, nexus_distrib_hierarchy_ld]
    forge.register(nexus_resource_hierarchy, ONTOLOGY_SCHEMAS_ID)

    # Generating the base payload for the brain annotation volume
    print("Pushing to Nexus: annotation volume...")
    brain_annotation_volume_payload = generate_payload_volumetric_data_layer(args.annotation_volume, 
        brain_annotation_volume_id,
        "BBP Mouse Brain Annotation Volume, 25µm",
        "This raster volume contains the brain region annotation as IDs, including the separation of cortical layers 2 and 3.",
        "BrainParcellationDataLayer",
        atlas_release_id,
        srs_id,
        root_node,
        "PARCELLATION_ID",
        25,
    )
    nexus_resource_annotation_volume = Resource.from_json(brain_annotation_volume_payload)
    nexus_resource_annotation_volume.distribution = forge.attach(args.annotation_volume, content_type="application/nrrd")
    forge.register(nexus_resource_annotation_volume, schema_id=VOLUMETRICDATALAYER_SCHEMAS_ID)

    # Generating the base payload for the brain annotation volume
    print("Pushing to Nexus: template volume...")
    brain_template_payload = generate_payload_volumetric_data_layer(args.template_volume, 
        brain_template_volume_id,
        "BBP Mouse Brain Template Volume, 25µm",
        "Raster volume of the brain template. This originaly comes from AIBS CCF (25µm)",
        "BrainTemplateDataLayer",
        atlas_release_id,
        srs_id,
        root_node,
        "LUMINANCE",
        25,
    )
    nexus_resource_template_volume = Resource.from_json(brain_template_payload)
    nexus_resource_template_volume.distribution = forge.attach(args.template_volume, content_type="application/nrrd")
    forge.register(nexus_resource_template_volume, schema_id=VOLUMETRICDATALAYER_SCHEMAS_ID)

    # Generating the base payload for the Atlas Release
    print("Pushing to Nexus: Atlas Release...")
    atlas_release_payload = generate_payload_atlas_release(atlas_release_id,
        "Blue Brain Atlas",
        "The official Atlas of the Blue Brain Project, derivated from AIBS Mouse CCF v3 (2017)",
        brain_template_volume_id,
        brain_ontology_id,
        brain_annotation_volume_id,
        srs_id
    )
    nexus_resource_atlas_release = Resource.from_json(atlas_release_payload)
    forge.register(nexus_resource_atlas_release, schema_id=ATLASRELEASE_SCHEMAS_ID)

    # Writing the text file that contains the ID of this atlasRelease
    open(args.out_atlasrelease_id_file, 'w').write(atlas_release_id)

if __name__ == "__main__":
    main()
