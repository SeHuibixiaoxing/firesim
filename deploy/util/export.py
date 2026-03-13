import os
import shlex

from typing import Set


def create_export_string(vars: Set[str]) -> str:
    """For v in vars, if v exists, then add it to an export string"""
    export_shell_env_vars = set()
    for v in vars:
        if v in os.environ:
            # Quote values so variables containing spaces (e.g. SBT_OPTS/JAVA_TOOL_OPTIONS)
            # are exported as a single assignment token.
            export_shell_env_vars.add(f"{v}={shlex.quote(os.environ[v])}")
    return (
        ("export " + " ".join(export_shell_env_vars))
        if export_shell_env_vars
        else "true"
    )
