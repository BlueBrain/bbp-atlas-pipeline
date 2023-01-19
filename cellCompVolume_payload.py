def create_payload(forge, atlas_release_id):

    # Density resources annotated with Mtypes without layers are note released
    query_layer = f"""
    SELECT DISTINCT ?s
    WHERE {{
            ?s a METypeDensity ;
                atlasRelease <{atlas_release_id}>; 
                annotation / hasBody / label ?mtype_label ;
                brainLocation / brainRegion ?brainRegion ;  
                brainLocation / layer ?layer;
                distribution ?distribution .
            ?distribution name ?nrrd_file ;
            contentUrl ?contentUrl .
    }}
    """
    all_resources_with_layer = forge.sparql(query_layer, limit=1000, debug=False)
    resources = [forge.retrieve(id = r.s) for r in tqdm(all_resources_wiht_layer)]
    print(f"{len(resources)} ME-type dentisities with layer found")

    # Get Generic{Excitatory,Inhibitory}Neuron
    for excInh in ["Excitatory", "Inhibitory"]:
        query_gen = f"""
        SELECT DISTINCT ?s
        WHERE {{
                ?s a METypeDensity ;
                    atlasRelease <{atlas_release_id}>; 
                    annotation / hasBody <https://bbp.epfl.ch/ontologies/core/bmo/Generic{excInh}NeuronMType> ;
                    annotation / hasBody <https://bbp.epfl.ch/ontologies/core/bmo/Generic{excInh}NeuronEType> ;
                    brainLocation / brainRegion ?brainRegion ;
                    distribution ?distribution .
                ?distribution name ?nrrd_file ;
                    contentUrl ?contentUrl .
        }}
        """
        generic_resources = forge.sparql(query_gen, limit=1000, debug=False)
        assert len(generic_resource) == 1
        generic_resource = forge.retrieve(id = generic_resources[0].s)
        resources.append(generic_resource)

    print(f"{len(resources)} ME-type densities will be released, including generic ones")

    metype_annotations = [(a.hasBody for a in r.annotation) for r in resources] 
    etype_annotations = [a.hasBody for r in resources for a in r.annotation if "ETypeAnnotation" in a.type]

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
    grouped_by_metype = {"hasPart": []}
    for m_id, m in mtype_to_etype.items():
        m_content = {"@id": m_id, "label": m["label"], "about": ["https://neuroshapes.org/MType"], "hasPart": []}    
        for kv, vv in m.items():
            if kv != "label":
                kv_content = {"@id": kv, "label": vv["label"], "about": ["https://neuroshapes.org/EType"], "hasPart": []}
                for kvv, vvv in vv.items():
                    if kvv != "label":
                        kv_content["hasPart"].append( {"@id": kvv, "@type": vvv["type"], "_rev": vvv["_rev"]} )
                        m_content["hasPart"].append( kv_content )
        grouped_by_metype["hasPart"].append(m_content)

    local_file_name = "./cellCompositionVolume_distribution.json"
    with open(local_file_name, "w") as f:
        json.dump(grouped_by_metype, f)

    return payload
