#!/bin/bash

echo "creating archive called '${1:-metrics}.tar.xz' of current analysis"
tar cJf "${1:-metrics}.tar.xz" libs index.html clean_metrics.json
