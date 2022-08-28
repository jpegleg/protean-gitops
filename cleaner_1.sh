#!/usr/bin/env bash
find /opt/protean-gitops/ -name "*.log" -size 1k -exec rm -f {} \;
