import os

token_username = os.environ["SERVICE_TOKEN_USERNAME"]
token_password = os.environ["SERVICE_TOKEN_PASSWORD"]


def test_cli():
    working_dir = "tests/working_dir"
    rule_total = {"push_atlas_datasets": "74"}

    for rule, total in rule_total.items():
        cli_command = f"bbp-atlas --target-rule {rule} " \
            f"--snakemake-options '--config WORKING_DIR={working_dir} " \
            f"TOKEN_USERNAME={token_username} TOKEN_PASSWORD={token_password} SERVICE_TOKEN=True  -c1  --dryrun'"
        result = os.popen(cli_command).read()

        if "Exception" in result:
            print(result)
            assert False

        lines = result.splitlines()
        for line in lines:
            if line.startswith("total"):
                if total in line:
                    # Found the expected total number of rules
                    break
                else:
                    print(f"Unexpected total number of rules for '{rule}':")
                    print(result)
                    assert False
