'''
This is in charge of pushing the NRRD region masks

'''

import uuid
import glob
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
        help="Nexus ID for the Spatial Reference System")

    parser.add_argument(
        "--hierarchy",
        dest="hierarchy",
        required=True,
        metavar="<FILE PATH>",
        help="The hierarchy JSON file, sometimes called 1.json")

    parser.add_argument(
        "--region-mask-volume-dir",
        dest="region_mask_volume_dir",
        required=True,
        metavar="<DIR PATH>",
        help="The directory containing the NRRD region masks")

    parser.add_argument(
        "--atlasrelease-id",
        dest="atlasrelease_id",
        required=False,
        metavar="<NEXUS ID>",
        help="Nexus ID of the AtlasRelease Nexus Resource the volumes are linked to")

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

    srs_id = args.nexus_id_aibs_ccf_srs
    atlas_release_id = args.atlasrelease_id

    # Reading the brain region ontology, to later being able to generate
    # better names that include brain region labels
    brain_onto_json = json.loads(open(args.hierarchy, "r").read())
    # sometimes, the 1.json has its content in a "msg" sub prop (the original version has).
    # and some other versions don't. Here we deal with both
    if "msg" in brain_onto_json:
        onto_flat_tree = TreeIndexer.flattenTree(brain_onto_json['msg'][0])
    else:
        onto_flat_tree = TreeIndexer.flattenTree(brain_onto_json)

    # finding all the masks
    masks_nrrd_paths = glob.glob(f"{args.region_mask_volume_dir}/*.nrrd")

    print("Pushing to Nexus: region masks volume...")
    for i in range(0, len(masks_nrrd_paths)):
        mask_filepath = masks_nrrd_paths[i]
        region_id = int(os.path.basename(mask_filepath).split(".")[0])
        region_node = onto_flat_tree[region_id]
        region_mask_nexus_id = forge.format("identifier", str(uuid.uuid4()))
        print(f"[{i+1}/{len(masks_nrrd_paths)}] ", region_node["name"], " --> ", region_mask_nexus_id)

        region_mask_volume_payload = generate_payload_volumetric_data_layer(mask_filepath, 
            region_mask_nexus_id,
            f"Mask Volume of {region_node['name']}, 25µm",
            f"Blue Brain Atlas mask raster volume of the region {region_node['name']}, at resolution 25µm",
            "BrainParcellationMask",
            atlas_release_id,
            srs_id,
            region_node,
            "MASK",
            25,
        )
        region_mask_volume_resource = Resource.from_json(region_mask_volume_payload)
        region_mask_volume_resource.distribution = forge.attach(mask_filepath, content_type="application/nrrd")
        forge.register(region_mask_volume_resource, schema_id=VOLUMETRICDATALAYER_SCHEMAS_ID)

if __name__ == "__main__":
    main()
