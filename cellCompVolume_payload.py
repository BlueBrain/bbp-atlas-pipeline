import json

hasPart_key = "hasPart"


def create_payload(forge, atlas_release_id, output_file, n_densities_expected,
                   endpoint, bucket, tag=None):
    base_query = f"""
            ?s a METypeDensity ;
            atlasRelease <{atlas_release_id}>;
            brainLocation / brainRegion ?brainRegion ;
            distribution ?distribution ;
            _deprecated ?_deprecated;
            _project ?_project;
            """

    # Density Resources without annotation are not released in the CellCompositionVolume
    query_annotation = """
        SELECT DISTINCT ?s
        WHERE {""" + base_query + """
            annotation / hasBody / label ?mtype_label .
            ?distribution name ?nrrd_file ;
            contentUrl ?contentUrl .
            Filter (?_deprecated = 'false'^^xsd:boolean)
            Filter (?_project = <"""+endpoint+"""/projects/"""+bucket+""">)
        }"""
    all_resources_with_ann = forge.sparql(query_annotation, limit=3500, debug=False)
    print(f"{len(all_resources_with_ann)} ME-type densities with annotation found in total, filtering those with tag '{tag}'")

    resources = filter_by_tag(all_resources_with_ann, tag, forge)
    n_res_with_tag = len(resources)
    print(f"{n_res_with_tag} ME-type densities with annotation found with tag '{tag}'")
    assert n_res_with_tag == n_densities_expected, (f"The number of ME-type densities "
        f"found with tag '{tag}' ({n_res_with_tag}) does not match the expected number ({n_densities_expected})")

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
        generic_resources = filter_by_tag(all_generic_resources, tag, forge)
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


def filter_by_tag(all_resources, tag, forge):
    if not tag:
        return all_resources

    tagged_resources = []
    for count, res in enumerate(all_resources):
        print(f"Retrieving Resource {count} of {len(all_resources)}")
        try:
            retrieved_res = forge.retrieve(id=res.s, version=tag)
            if retrieved_res is not None:
                tagged_resources.append(retrieved_res)
        except Exception:
            pass
    return tagged_resources
