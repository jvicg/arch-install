#!/usr/bin/env python
# -*- coding: utf-8 -*-

from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

import os
import re
import json
import subprocess
from typing import List

class Disk:
    MIN_DISK_SIZE = 20.00  # Min disk size on GB

    def __init__(self, name: str, facts: dict):
        self.name = name
        self.facts = facts
        self.size = self.facts["ansible_devices"][self.name]["size"]
        self.is_valid = self.check_if_valid()
        self.is_partitioned = self.check_if_partitioned()
        self.is_mounted = self.check_if_mounted()

    def __str__(self):
        return f"name={self.name}, mounted={self.is_mounted}, partitioned={self.is_partitioned}"

    def check_if_valid(self) -> bool:
        """If the disk has a minimum size and has the proper name (doesn't match exclude regex)
        """
        disk_size = float(self.size.split()[0])
        exclude_regex = r"^(?!dm-)"

        return re.search(exclude_regex, self.name) and disk_size > self.MIN_DISK_SIZE

    def check_if_partitioned(self) -> bool:
        """If the dictionary partitions associate to the device is not empty, means that the disk is partitioned
        """
        return len(self.facts["ansible_devices"][self.name]["partitions"]) > 0

    def check_if_mounted(self) -> bool:
        """Check if the disk is already mounted
        """
        for mount in self.facts["ansible_mounts"]:
            if f"/dev/{self.name}" in mount:
                return True
        
        return False

def gather_facts(facts_dir: str, host : str="localhost", force: bool=False) -> dict:
    """Gather Ansible's facts of a given host an store them into a given directory

    Args:
        facts_dir (str): Directory where the Ansible's facts will be store.
        host (str, optional): Host to gather facts from. Defaults to "localhost".
        force (bool, optional): Gather facts even if the facts file exists already.
    """
    facts_command = [
        "ansible", host, "-m", "ansible.builtin.setup", "--tree", facts_dir
    ]
    
    facts_file = os.path.join(facts_dir, host) 

    try:
        if force or not os.path.isfile(facts_file):
            subprocess.run(facts_command, check=True, capture_output=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        # Read the content of the output
        with open(facts_file, "r") as f:
            facts = json.load(f)
        
        return facts["ansible_facts"]
    
    except (subprocess.CalledProcessError, OSError, Exception):
        raise

def get_valid_disks() -> List[Disk]:
    """Obtain a list with the valid disks
    """
    try:
        facts_dir = os.path.join(os.getcwd(), "facts")
        facts = gather_facts(facts_dir)

        disks = []

        for disk_name in facts["ansible_devices"].keys():
            disk = Disk(disk_name, facts)

            if disk.is_valid:
                disks.append(disk)
        
        return disks
    
    except (subprocess.CalledProcessError, OSError, Exception):
        raise
