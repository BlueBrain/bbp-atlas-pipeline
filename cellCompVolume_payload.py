import json

hasPart_key = "hasPart"


def create_payload(forge, atlas_release_id, output_file, n_layer_densities, endpoint, org, project, tag=None):
    base_query = f"""
            ?s a METypeDensity ;
            atlasRelease <{atlas_release_id}>;
            brainLocation / brainRegion ?brainRegion ;
            distribution ?distribution ;
            _deprecated ?_deprecated;
            _project ?_project;
            """

    # Density resources annotated with Mtypes without layers are not released
    query_layer = """
        SELECT DISTINCT ?s
        WHERE {""" + base_query + """
            annotation / hasBody / label ?mtype_label ;
            brainLocation / layer ?layer .
            ?distribution name ?nrrd_file ;
            contentUrl ?contentUrl .
            Filter (?_deprecated = 'false'^^xsd:boolean)
            Filter (?_project = <"""+endpoint+"""/projects/"""+org+"""/"""+project+""">)
        }"""
    all_resources_with_layer = forge.sparql(query_layer, limit=3500, debug=False)
    print(f"{len(all_resources_with_layer)} ME-type densities with layer found in total, filtering those with tag '{tag}'")
    resources = []
    for r in all_resources_with_layer:
        try:
            resources.append(forge.retrieve(id = r.s, version=tag))
        except Exception as e:
            pass
    resources = [res for res in resources if res is not None]
    n_res_with_layer = len(resources)
    print(f"{n_res_with_layer} ME-type densities with layer found with tag '{tag}'")
    assert n_res_with_layer == n_layer_densities

    # Get Generic{Excitatory,Inhibitory}Neuron
    for excInh in ["Excitatory", "Inhibitory"]:
        query_gen = f"""
            SELECT DISTINCT ?s
            WHERE {{""" + base_query + f"""
            annotation / hasBody <https://bbp.epfl.ch/ontologies/core/bmo/Generic{excInh}NeuronMType> ;
            annotation / hasBody <https://bbp.epfl.ch/ontologies/core/bmo/Generic{excInh}NeuronEType> .
            ?distribution name ?nrrd_file ;
            contentUrl ?contentUrl .
            Filter (?_deprecated = 'false'^^xsd:boolean)
            }}"""
        all_generic_resources = forge.sparql(query_gen, limit=1000, debug=False)
        generic_resources = []
        for r in all_generic_resources:
            try:
                generic_resources.append(forge.retrieve(id = r.s, version=tag))
            except Exception as e:
                pass
        generic_resources = [res for res in generic_resources if res is not None]
        assert len(generic_resources) == 1
        resources.extend(generic_resources)

    print(f"{len(resources)} ME-type densities will be released, including generic ones (tag '{tag}')")

    metype_annotations = [(a.hasBody for a in r.annotation) for r in resources] 

    mtype_to_etype = {}
    for i, metype_annotation_gen in enumerate(metype_annotations):
        metype_annotation_gen_list = list(metype_annotation_gen)
        if "MType" in metype_annotation_gen_list[0].type:
            if metype_annotation_gen_list[0].id not in mtype_to_etype:
                mtype_to_etype[metype_annotation_gen_list[0].id] = {"label": metype_annotation_gen_list[0].label}
            if "EType" in metype_annotation_gen_list[1].type and metype_annotation_gen_list[1].id not in mtype_to_etype[metype_annotation_gen_list[0].id]:
                mtype_to_etype[metype_annotation_gen_list[0].id][metype_annotation_gen_list[1].id] = {"label": metype_annotation_gen_list[1].label}
            if resources[i].id not in mtype_to_etype[metype_annotation_gen_list[0].id][metype_annotation_gen_list[1].id]:
                mtype_to_etype[metype_annotation_gen_list[0].id][metype_annotation_gen_list[1].id][resources[i].id] = {"type": resources[i].type, "_rev": resources[i]._store_metadata._rev}

    # CellCompositionVolume structure
    grouped_by_metype = {hasPart_key: []}
    for m_id, m in mtype_to_etype.items():
        m_content = {"@id": m_id, "label": m["label"], "about": ["https://neuroshapes.org/MType"], hasPart_key: []}
        for e_id, e in m.items():
            if e_id != "label":
                e_content = {"@id": e_id, "label": e["label"], "about": ["https://neuroshapes.org/EType"], hasPart_key: []}
                for res_id, res in e.items():
                    if res_id != "label":
                        e_content[hasPart_key].append({"@id": res_id, "@type": res["type"], "_rev": res["_rev"]})
                        m_content[hasPart_key].append(e_content)
        grouped_by_metype[hasPart_key].append(m_content)

    with open(output_file, "w") as f:
        json.dump(grouped_by_metype, f)

    return grouped_by_metype
