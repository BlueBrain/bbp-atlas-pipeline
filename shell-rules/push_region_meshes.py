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


REGION_MESH_SCHEMAS_ID = "https://neuroshapes.org/dash/brainparcellationmesh"


def generate_payload_region_mesh(id, name, description, atlas_release_id, srs_id, region_node):
    return {
        "@id": id,
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
              "@id": f"mba:{region_node['id']}",
              "label": region_node["name"],
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
        "--region-mesh-dir",
        dest="region_mesh_dir",
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
    mesh_paths = glob.glob(f"{args.region_mesh_dir}/*.obj")

    print("Pushing to Nexus: region meshes...")
    for i in range(0, len(mesh_paths)):
        mesh_filepath = mesh_paths[i]
        region_id = int(os.path.basename(mesh_filepath).split(".")[0])
        region_node = onto_flat_tree[region_id]
        region_mesh_nexus_id = forge.format("identifier", str(uuid.uuid4()))
        print(f"[{i+1}/{len(mesh_paths)}] ", region_node["name"], " --> ", region_mesh_nexus_id)

        region_mesh_payload = generate_payload_region_mesh(region_mesh_nexus_id,
            f"Mesh of {region_node['name']}",
            f"Blue Brain Atlas mesh of the region {region_node['name']}",
            atlas_release_id,
            srs_id,
            region_node
        )

        region_mask_volume_resource = Resource.from_json(region_mesh_payload)
        region_mask_volume_resource.distribution = forge.attach(mesh_filepath, content_type="application/obj")
        forge.register(region_mask_volume_resource, schema_id=REGION_MESH_SCHEMAS_ID)

if __name__ == "__main__":
    main()
