from nrrdhlp.region_annotations import AnnotationWrapper

forge = None
# a "forge" argument is needed in the next line to fetch the hierarchy/annotation in case "use_{hier,anno}_file" is None
w = AnnotationWrapper(forge, method_dict={"root": "create"}, use_hier_file=snakemake.input.hierarchy, use_anno_file=snakemake.input.annotation)
w.fix(fn_hier_out=snakemake.output.hierarchy, fn_ann_out=snakemake.output.annotation, fn_log=snakemake.log[0])
