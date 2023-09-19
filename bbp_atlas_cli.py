import os
import click
import json
import yaml
import re

@click.command()
@click.option("--target-rule",
              type=click.STRING,
              required=True,
              help="The target rule of the pipeline to execute")
@click.option("--user-config-file",
              type=click.Path(exists=True),
              required=False,
              help="The user configuration to customize the pipeline")
@click.option("--snakemake-options",
              type=click.STRING,
              required=False,
              help="String of options to pass to the snakemake command")
def execute_pipeline(target_rule, user_config_file, snakemake_options):
    pipeline_command = "snakemake"
    if not user_config_file:
        pipeline_command += " --snakefile snakefile"
    else:
        from blue_brain_token_fetch.Token_refresher import TokenFetcher
        from pipeline_validator.pipeline_validator import pipeline_validator
        from customize_pipeline.customize_pipeline import get_merge_rule_name, get_var_path_map

        with open("config.yaml") as pipeline_config_file:
            pipeline_config = yaml.safe_load(pipeline_config_file.read().strip())
        keycloak_config = pipeline_config["KEYCLOAK_CONFIG"]
        working_dir = pipeline_config["WORKING_DIR"]
        token_fetcher = TokenFetcher(keycloak_config_file=keycloak_config)

        with open("rules_config_dir_templates/push_dataset_config_template.yaml", "r") as push_dataset_config_template:
            push_dataset_config = re.sub("{WORKING_DIR}", working_dir, push_dataset_config_template.read())
            push_dataset_config_dict = yaml.safe_load(push_dataset_config.strip())
        with open("customize_pipeline/available_vars.yaml", "r") as vars_file:
            available_vars = yaml.safe_load(vars_file.read().strip())
        input_group = "input"
        var_path_map = get_var_path_map(available_vars[input_group], push_dataset_config_dict)
        whitelisted_vars = [f"{input_group}.{var}" for var in var_path_map.keys()]

        pipeline_validator(user_config_file, token_fetcher.getAccessToken(), whitelisted_vars)

        user_config_json = json.load(open(user_config_file))
        priority_rules = []
        for user_rule_name in [user_rule["rule"] for user_rule in user_config_json["rules"]]:
            merge_rule_name = get_merge_rule_name(user_rule_name)
            if target_rule == user_rule_name:
                target_rule = merge_rule_name
            else:
                priority_rules.append(merge_rule_name)

        pipeline_command += " --snakefile customize_pipeline/custom_snakefile"
        if priority_rules:
            pipeline_command += f" --prioritize {' '.join(priority_rules)}"

    if snakemake_options:
        pipeline_command += " " + snakemake_options

    pipeline_command += " " + target_rule
    os.system(pipeline_command)
