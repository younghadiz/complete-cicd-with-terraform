#!/usr/bin/env python3
"""Build an SSH known_hosts entry from authenticated EC2 console output."""

import argparse
import base64
import json
from pathlib import Path
import re
import subprocess
import time


def aws_json(*arguments):
    result = subprocess.run(
        [
            "aws",
            "--no-cli-pager",
            "--cli-connect-timeout", "10",
            "--cli-read-timeout", "20",
            "ec2",
            *arguments,
            "--output", "json",
        ],
        check=True,
        capture_output=True,
        text=True,
        timeout=40,
    )
    return json.loads(result.stdout)


def extract_key(console):
    blocks = re.findall(
        r"BEGIN SSH HOST KEY KEYS-----\s*(.*?)"
        r"-----END SSH HOST KEY KEYS",
        console,
        flags=re.DOTALL,
    )

    keys = {
        match
        for block in blocks
        for match in re.findall(
            r"\bssh-ed25519[ \t]+([A-Za-z0-9+/=]+)",
            block,
        )
    }

    if not keys:
        return None

    if len(keys) != 1:
        raise ValueError("Console output contains multiple ED25519 host keys.")

    key = keys.pop()
    blob = base64.b64decode(key, validate=True)

    # OpenSSH ED25519 wire format: key type followed by a 32-byte public key.
    prefix = b"\x00\x00\x00\x0bssh-ed25519\x00\x00\x00\x20"
    if not blob.startswith(prefix) or len(blob) != len(prefix) + 32:
        raise ValueError("Invalid ED25519 public-key encoding.")

    return key


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--instance-id", required=True)
    parser.add_argument("--host", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    response = aws_json(
        "describe-instances",
        "--instance-ids", args.instance_id,
    )
    instances = [
        instance
        for reservation in response.get("Reservations", [])
        for instance in reservation.get("Instances", [])
    ]

    if len(instances) != 1:
        raise ValueError("Expected exactly one EC2 instance.")

    if instances[0].get("PublicIpAddress") != args.host:
        raise ValueError("Terraform address does not match the EC2 instance.")

    deadline = time.monotonic() + 600

    while time.monotonic() < deadline:
        response = aws_json(
            "get-console-output",
            "--instance-id", args.instance_id,
            "--latest",
        )

        if response.get("InstanceId") != args.instance_id:
            raise ValueError("Console output belongs to an unexpected instance.")

        # AWS CLI decodes the console output.
        key = extract_key(response.get("Output") or "")

        if key:
            destination = Path(args.output)
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_text(f"{args.host} ssh-ed25519 {key}\n")
            destination.chmod(0o600)
            print(f"Prepared trusted SSH host key for {args.instance_id}.")
            return

        time.sleep(5)

    raise TimeoutError("EC2 console did not provide an ED25519 host key.")


if __name__ == "__main__":
    main()
