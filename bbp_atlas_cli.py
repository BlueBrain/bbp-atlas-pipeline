import os
import click
import json
import yaml
import re


@click.command()
@click.option("--target-rule",
              type=click.STRING, required=False,
              help="The target rule of the pipeline to execute (required without a user configuration)")
@click.option("--user-config-file",
              type=click.Path(), required=False,
              help="The user configuration to customize the pipeline")
@click.option("--repo-path",
              type=click.Path(exists=True), required=False, default=".",
              help="The path of the pipeline repository")
@click.option("--snakemake-options",
              type=click.STRING, required=False, default="",
              help="String of options to pass to the snakemake command")
@click.option("--service-token",
              is_flag=True, default=False,
              help="Flag to use a service token instead of a user token",
              show_default=True)
@click.option("--token-username",
              type=click.STRING, required=False,
              help="Username for token fetcher")
@click.option("--token-password",
              type=click.STRING, required=False,
              help="Password for token fetcher")
def execute_pipeline(target_rule, user_config_file, repo_path, snakemake_options,
                     service_token, token_username, token_password):
    pipeline_command = "snakemake"
    if not user_config_file:
        if not target_rule:
            raise Exception("A target rule is required if no user configuration is provided")
    else:
        user_config_path = os.path.join(repo_path, user_config_file)
        if not os.path.isfile(user_config_path):
            raise FileNotFoundError(f"--user-config-file {user_config_path} not found.")

        if target_rule:
            raise Exception(f"When a user configuration is provided (--user-config-file {user_config_file}),"
                            " the target rule must be specified in the user configuration"
                            " file (first key) and not via the '--target-rule' argument.")
        if "--snakefile " in snakemake_options:
            raise Exception("The --snakefile option can not be used together with --user-config-file")

        from blue_brain_token_fetch.token_fetcher_user import TokenFetcherUser
        from blue_brain_token_fetch.token_fetcher_service import TokenFetcherService
        from pipeline_validator.pipeline_validator import pipeline_validator
        from customize_pipeline.customize_pipeline import get_merge_rule_name, get_var_path_map

        with open(os.path.join(repo_path, "config.yaml")) as pipeline_config_file:
            pipeline_config = yaml.safe_load(pipeline_config_file.read().strip())
        keycloak_config = os.path.join(repo_path, pipeline_config["KEYCLOAK_CONFIG"])
        working_dir = pipeline_config["WORKING_DIR"]
        if not service_token:
            token_fetcher = TokenFetcherUser(token_username, token_password, keycloak_config_file=keycloak_config)
        else:
            token_fetcher = TokenFetcherService(token_username, token_password, keycloak_config_file=keycloak_config)

        with open(os.path.join(repo_path, "rules_config_dir_templates/push_dataset_config_template.yaml"), "r") as push_dataset_config_template:
            push_dataset_config = re.sub("{WORKING_DIR}", working_dir, push_dataset_config_template.read())
            push_dataset_config_dict = yaml.safe_load(push_dataset_config.strip())
        with open(os.path.join(repo_path, "customize_pipeline/available_vars.yaml"), "r") as vars_file:
            available_vars = yaml.safe_load(vars_file.read().strip())
        input_group = "input"
        var_path_map = get_var_path_map(available_vars[input_group], push_dataset_config_dict)
        whitelisted_vars = [f"{input_group}.{var}" for var in var_path_map.keys()]

        pipeline_validator(user_config_file, token_fetcher.get_access_token(), whitelisted_vars)

        user_config_json = json.load(open(user_config_path))
        target_rule = user_config_json["target_rule"]
        priority_rules = []
        for user_rule_name in [user_rule["rule"] for user_rule in user_config_json["rules"]]:
            merge_rule_name = get_merge_rule_name(user_rule_name)
            if target_rule == user_rule_name:
                target_rule = merge_rule_name
            else:
                priority_rules.append(merge_rule_name)

        snakemake_options += f" --snakefile {repo_path}/customize_pipeline/custom_snakefile"
        if priority_rules:
            snakemake_options += f" --prioritize {' '.join(priority_rules)}"

        user_config_option = f"USER_CONFIG={user_config_path}"
        full_user_config_option = f"--config {user_config_option}"
        if "--config" in snakemake_options:
            snakemake_options = snakemake_options.replace("--config", full_user_config_option)
        else:
            snakemake_options = "  ".join([full_user_config_option, snakemake_options])

    full_snakemake_options = " --printshellcmds"
    if snakemake_options:
        full_snakemake_options = " ".join([full_snakemake_options, snakemake_options])

    pipeline_command += " ".join([full_snakemake_options, target_rule])
    print("\nExecuting command:\n", pipeline_command)
    os.system(pipeline_command)
