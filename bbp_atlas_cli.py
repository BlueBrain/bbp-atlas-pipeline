import os
import click
import json
import yaml
import re


@click.command()
@click.option("--target-rule",
              type=click.STRING,
              required=False,
              help="The target rule of the pipeline to execute")
@click.option("--user-config-file",
              type=click.Path(exists=True),
              required=False,
              help="The user configuration to customize the pipeline")
@click.option("--repo-path",
              type=click.Path(exists=True),
              required=False,
              default=".",
              help="The path of the pipeline repository")
@click.option("--snakemake-options",
              type=click.STRING,
              required=False,
              help="String of options to pass to the snakemake command")
def execute_pipeline(target_rule, user_config_file, repo_path, snakemake_options):
    pipeline_command = "snakemake"
    if not user_config_file:
        if not target_rule:
            raise Exception("A target rule is required if no user configuration is provided")
    else:
        if target_rule:
            raise Exception(f"When a user configuration is provided (--user-config-file {user_config_file}),"
                            " the target rule must be specified in the user configuration"
                            " file (first key) and not via the '--target-rule' argument.")
        if "--snakefile " in snakemake_options:
            raise Exception("The --snakefile option can not be used together with --user-config-file")

        from blue_brain_token_fetch.token_fetcher_user import TokenFetcherUser
        from pipeline_validator.pipeline_validator import pipeline_validator
        from customize_pipeline.customize_pipeline import get_merge_rule_name, get_var_path_map

        with open(os.path.join(repo_path, "config.yaml")) as pipeline_config_file:
            pipeline_config = yaml.safe_load(pipeline_config_file.read().strip())
        keycloak_config = pipeline_config["KEYCLOAK_CONFIG"]
        working_dir = pipeline_config["WORKING_DIR"]
        token_fetcher = TokenFetcherUser(keycloak_config_file=keycloak_config)

        with open(os.path.join(repo_path, "rules_config_dir_templates/push_dataset_config_template.yaml"), "r") as push_dataset_config_template:
            push_dataset_config = re.sub("{WORKING_DIR}", working_dir, push_dataset_config_template.read())
            push_dataset_config_dict = yaml.safe_load(push_dataset_config.strip())
        with open(os.path.join(repo_path, "customize_pipeline/available_vars.yaml"), "r") as vars_file:
            available_vars = yaml.safe_load(vars_file.read().strip())
        input_group = "input"
        var_path_map = get_var_path_map(available_vars[input_group], push_dataset_config_dict)
        whitelisted_vars = [f"{input_group}.{var}" for var in var_path_map.keys()]

        pipeline_validator(user_config_file, token_fetcher.get_access_token(), whitelisted_vars)

        user_config_json = json.load(open(os.path.join(repo_path, user_config_file)))
        target_rule = user_config_json["target_rule"]
        priority_rules = []
        for user_rule_name in [user_rule["rule"] for user_rule in user_config_json["rules"]]:
            merge_rule_name = get_merge_rule_name(user_rule_name)
            if target_rule == user_rule_name:
                target_rule = merge_rule_name
            else:
                priority_rules.append(merge_rule_name)

        pipeline_command += f" --snakefile {repo_path}/customize_pipeline/custom_snakefile"
        if priority_rules:
            pipeline_command += f" --prioritize {' '.join(priority_rules)}"

    full_snakemake_options = " --printshellcmds"
    if snakemake_options:
        full_snakemake_options += " " + snakemake_options

    pipeline_command += " ".join([full_snakemake_options, target_rule])
    print("\nExecuting command:\n", pipeline_command)
    os.system(pipeline_command)
