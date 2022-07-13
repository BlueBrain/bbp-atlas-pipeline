'''
This is in charge of pushing the OBJ region meshes
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


def generate_payload_region_summary(id, name, description, atlas_release_id, srs_id, region_node, metadata):
    return {
        "@id": id,

        "@type": [
            "RegionSummary",
            "Entity"
        ],

        "name": name,

        "description": description,

        "brainLocation": {
            "atlasSpatialReferenceSystem": {
            "@id":srs_id,
            "@type": [
                "BrainAtlasSpatialReferenceSystem",
                "AtlasSpatialReferenceSystem"
            ]
            },
            "brainRegion": {
                "@id": f"mba:{region_node['id']}",
                "label": region_node["name"],
            }
        },

        "volume": {
            "ratio": metadata["regionVolumeRatioToWholeBrain"],
            "total": {
                "size": metadata["regionVolume"],
                "unitCode": "µm³"
            }
        },

        "adjacentTo": list(map(lambda region_id: { "@id": f"mba:{region_id}", "ratio": metadata["adjacentTo"][region_id]}, list(metadata["adjacentTo"].keys()))),

        "continuousWith": list(map(lambda region_id: { "@id": f"mba:{region_id}" }, metadata["continuousWith"])),

        "layers": metadata["layers"],



        "atlasRelease": {
            "@id": atlas_release_id,
            "@type": [
            "AtlasRelease",
            "BrainAtlasRelease",
            "Entity"
            ]
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
        help="Nexus ID for the Spatial Reference System")

    parser.add_argument(
        "--hierarchy",
        dest="hierarchy",
        required=True,
        metavar="<FILE PATH>",
        help="The hierarchy JSON file, sometimes called 1.json")

    parser.add_argument(
        "--region-metadata",
        dest="region_metadata",
        required=True,
        metavar="<FILE PATH>",
        help="The JSON file with brain region metadata")

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

    all_regions_meta = json.loads(open(args.region_metadata).read())
    region_keys = list(all_regions_meta.keys())

    for i in range(0, len(region_keys)):
        region_id = region_keys[i]
        region_node = onto_flat_tree[int(region_id)]
        summary_metadata = all_regions_meta[region_id]
        region_summary_nexus_id = forge.format("identifier", str(uuid.uuid4()))

        print(f"[{i+1}/{len(region_keys)}] ", region_node["name"], " --> ", region_summary_nexus_id)

        region_summary_payload = generate_payload_region_summary(region_summary_nexus_id,
            f"Region Summary of {region_node['name']}",
            f"Some details about the region {region_node['name']} as in the Blue Brain Atlas, regarding volume and neighbouring",
            atlas_release_id,
            srs_id,
            region_node,
            summary_metadata
        )

        region_summary_resource = Resource.from_json(region_summary_payload)
        forge.register(region_summary_resource)


if __name__ == "__main__":
    main()
