'''
This script should be launched after `push_atlasrelease.py` as it takes the ID
of the newly created atlas release in input.

This script is in charge of pushing the non-mask volume and volume that are not
directly involved in the composition of their atlasRelease (annotation + template), namely:
- placement hints volume
- direction vector volume
- orientation field volume

'''

import uuid
import argparse
import glob
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
  "VECTOR_3D": "vector3D",
  "LUMINANCE": "luminance",
  "MARKER_INTENSITY": "markerIntensity",
  "MASK": "mask",
  "POSITION_2D": "position2D",
  "POSITION_3D": "position3D",
  "QUANTITY": "quantity",
  "QUATERNION": "quaternion",
  "DISTANCE": "distance",
}

dataSampleModalitiesNumberOfComponents = {
  "PARCELLATION_ID": 1,
  "CELL_TYPE_ID": 1,
  "COLOR_RGB": 3,
  "COLOR_RGBA": 4,
  "EULER_ANGLE": 3,
  "GRADIENT_2D": 2,
  "GRADIENT_3D": 3,
  "VECTOR_3D": 3,
  "LUMINANCE": 1,
  "MARKER_INTENSITY": 1,
  "MASK": 1,
  "POSITION_2D": 2,
  "POSITION_3D": 3,
  "QUANTITY": 1,
  "QUATERNION": 4,
  "DISTANCE": 1,
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
        "--direction-vector-volume",
        dest="direction_vector_volume",
        required=True,
        metavar="<FILE PATH>",
        help="The NRRD direction vector volume (Eurler angles)")

    parser.add_argument(
        "--orientation-field-volume",
        dest="orientation_field_volume",
        required=True,
        metavar="<FILE PATH>",
        help="The NRRD orientation field volume (quaternions)")

    parser.add_argument(
        "--placement-hints-volume-dir",
        dest="placement_hints_volume_dir",
        required=True,
        metavar="<DIR PATH>",
        help="The NRRD placement hints volume directory")

    parser.add_argument(
        "--atlasrelease-id",
        dest="atlasrelease_id",
        required=False,
        metavar="<Nexus ID>",
        help="The ID of the AtlasRelease Nexus Resource the volumes are linked to")

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
    direction_vector_volume_id = forge.format("identifier", str(uuid.uuid4()))
    orientation_field_volume_id = forge.format("identifier", str(uuid.uuid4()))
    placement_hints_volume_id = forge.format("identifier", str(uuid.uuid4()))
    srs_id = args.nexus_id_aibs_ccf_srs
    atlas_release_id = args.atlasrelease_id

    print("ID of direction vector volume to push: ", direction_vector_volume_id)
    print("ID of orientation volume to push: ", orientation_field_volume_id)
    print("ID of placement hints volume to push: ", placement_hints_volume_id)
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
    
    # Generating the base payload for the direction vector volume
    print("Pushing to Nexus: direction vector volume...")
    direction_vector_volume_payload = generate_payload_volumetric_data_layer(args.direction_vector_volume, 
        direction_vector_volume_id,
        "BBP Mouse Brain Direction Vector Volume, 25µm",
        "This raster volume contains the direction vectors as (x, y, z)",
        "CellOrientationField",
        atlas_release_id,
        srs_id,
        root_node,
        "VECTOR_3D",
        25,
    )
    nexus_resource_direction_vector_volume = Resource.from_json(direction_vector_volume_payload)
    nexus_resource_direction_vector_volume.distribution = forge.attach(args.direction_vector_volume, content_type="application/nrrd")
    forge.register(nexus_resource_direction_vector_volume, schema_id=VOLUMETRICDATALAYER_SCHEMAS_ID)

    # Generating the base payload for the orientation field (quaternion) volume
    print("Pushing to Nexus: orientation field volume...")
    orientation_field_volume_payload = generate_payload_volumetric_data_layer(args.orientation_field_volume , 
        orientation_field_volume_id,
        "BBP Mouse Brain Orientation Field Volume, 25µm",
        "This raster volume contains orientation field as quaternions",
        "CellOrientationField",
        atlas_release_id,
        srs_id,
        root_node,
        "QUATERNION",
        25,
    )
    nexus_resource_orientation_field_volume = Resource.from_json(orientation_field_volume_payload)
    nexus_resource_orientation_field_volume.distribution = forge.attach(args.orientation_field_volume, content_type="application/nrrd")
    forge.register(nexus_resource_orientation_field_volume, schema_id=VOLUMETRICDATALAYER_SCHEMAS_ID)

    # Generating the base payload for the placement hints volumes.
    # There are multiple nrrd files, one for each cortical layer and one for pia
    placement_hints_nrrd_paths = glob.glob(f"{args.placement_hints_volume_dir}/*.nrrd")
    print("Pushing to Nexus: placement hints volume...")
    placement_hints_volume_payload = generate_payload_volumetric_data_layer(placement_hints_nrrd_paths[0] , 
        placement_hints_volume_id,
        "BBP Mouse Brain Placement Hints Volumes, 25µm",
        "This raster volume contains placement hints volumes for all the cortical layers",
        "PlacementHintsDataLayer",
        atlas_release_id,
        srs_id,
        root_node,
        "DISTANCE",
        25,
    )
    nexus_resource_orientation_field_volume = Resource.from_json(placement_hints_volume_payload)
    placemement_hints_distributions = []
    for nrrd_path in placement_hints_nrrd_paths:
        placemement_hints_distributions.append(forge.attach(nrrd_path, content_type="application/nrrd"))

    # There is also a validation json file
    placement_hints_json_paths = glob.glob(f"{args.placement_hints_volume_dir}/*.json")
    for json_path in placement_hints_json_paths:
        placemement_hints_distributions.append(forge.attach(json_path, content_type="application/json"))

    nexus_resource_orientation_field_volume.distribution = placemement_hints_distributions
    forge.register(nexus_resource_orientation_field_volume, schema_id=VOLUMETRICDATALAYER_SCHEMAS_ID)


if __name__ == "__main__":
    main()
