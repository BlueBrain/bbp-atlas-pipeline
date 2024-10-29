import os

service_token_settings = os.environ["SERVICE_TOKEN_SETTINGS"]


def test_cli():
    working_dir = "tests/working_dir"
    rule_total = {"push_atlas_datasets": "63"}

    for rule, total in rule_total.items():
        cli_command = f"bbp-atlas --target-rule {rule} " \
            f"--snakemake-options '--config WORKING_DIR={working_dir} " \
            f"{service_token_settings}  -c1  --dryrun'"
        result = os.popen(cli_command).read()

        if any(x in result for x in ["Exception", "Invalid"]):
            print(result)
            assert False

        lines = result.splitlines()
        for line in lines:
            if line.startswith("total"):
                assert total in line, (f"Unexpected total number of rules for '{rule}' (expected: {total}):\n"
                                       f"{result}")
