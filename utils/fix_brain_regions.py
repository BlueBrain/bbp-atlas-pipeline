import json
from os.path import join

DATA_FOLDER = "../data/"
# Fixed 1.json (https://bbp.epfl.ch/nexus/web/neurosciencegraph/datamodels/resources/http%3A%2F%2Fbbp.epfl.ch%2Fneurosciencegraph%2Fontologies%2Fmba)
# from Dimitri https://bluebrainproject.slack.com/archives/C03G4KZJ735/p1652960553033779

name_regex = ".+, layer [1-6](\/3)?[a|b]?$"
acronym_regex = "[a-zA-Z]+[1-6](\/3)?[a|b]?$"

# key: old name, value: new name
corrections = {}
corrections["Somatomotor areas, Layer 1"] = "Somatomotor areas, layer 1"
corrections["Somatomotor areas, Layer 2/3"] = "Somatomotor areas, layer 2/3"
corrections["Somatomotor areas, Layer 5"] = "Somatomotor areas, layer 5"
corrections["Somatomotor areas, Layer 6a"] = "Somatomotor areas, layer 6a"
corrections["Somatomotor areas, Layer 6b"] = "Somatomotor areas, layer 6b"
corrections["Primary motor area, Layer 1"] = "Primary motor area, layer 1"
corrections["Primary motor area, Layer 2/3"] = "Primary motor area, layer 2/3"
corrections["Primary motor area, Layer 5"] = "Primary motor area, layer 5"
corrections["Primary motor area, Layer 6a"] = "Primary motor area, layer 6a"
corrections["Primary motor area, Layer 6b"] = "Primary motor area, layer 6b"
corrections["Anterior cingulate area, ventral part, 6a"] = "Anterior cingulate area, ventral part, layer 6a"
corrections["Anterior cingulate area, ventral part, 6b"] = "Anterior cingulate area, ventral part, layer 6b"
corrections["Ectorhinal area/Layer 1"] = "Ectorhinal area, layer 1"
corrections["Ectorhinal area/Layer 2/3"] = "Ectorhinal area, layer 2/3"
corrections["Ectorhinal area/Layer 5"] = "Ectorhinal area, layer 5"
corrections["Ectorhinal area/Layer 6a"] = "Ectorhinal area, layer 6a"
corrections["Ectorhinal area/Layer 6b"] = "Ectorhinal area, layer 6b"
corrections["Rostrolateral lateral visual area,layer 5"] = "Rostrolateral lateral visual area, layer 5" 
corrections["Laterolateral anterior visual area,layer 5"] = "Laterolateral anterior visual area, layer 5"
corrections["Mediomedial anterior visual area,layer 5"] = "Mediomedial anterior visual area, layer 5"
corrections["Mediomedial posterior visual area,layer 5"] = "Mediomedial posterior visual area, layer 5"
corrections["Medial visual area,layer 5"] = "Medial visual area, layer 5"
corrections["Rostrolateral area, layer 1"] = "Rostrolateral visual area, layer 1" 
corrections["Rostrolateral area, layer 2/3"] = "Rostrolateral visual area, layer 2/3" 
corrections["Rostrolateral area, layer 4"] = "Rostrolateral visual area, layer 4" 
corrections["Rostrolateral area, layer 5"] = "Rostrolateral visual area, layer 5" 
corrections["Rostrolateral area, layer 6a"] = "Rostrolateral visual area, layer 6a" 
corrections["Rostrolateral area, layer 6b"] = "Rostrolateral visual area, layer 6b"

jsoncontent = json.loads(open(join(DATA_FOLDER, "1.json"), "r").read())


def correct_hierarchy_names(current, corrections):
    if len(corrections) >0:
        for i, child in enumerate(current["children"]):
            current["children"][i] = correct_hierarchy_names(child, corrections)
        old_name = current["name"]
        if old_name in corrections.keys():
            current["name"] = corrections[old_name]
            del corrections[old_name]
    return current

correct_hierarchy_names(jsoncontent["msg"][0], corrections)

with open(join(DATA_FOLDER, "mba_corrected.json"), 'w') as fp:
    json.dump(jsoncontent, fp, indent=1)
