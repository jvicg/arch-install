#!/usr/bin/env python
# -*- coding: utf-8 -*-

from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

import utils

valid_disks = utils.get_valid_disks()

for disk in valid_disks:
    print(disk)