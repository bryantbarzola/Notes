#!/bin/bash
cd "$(dirname "$0")" || exit 1
exec env PYTHONPATH=src .venv/bin/python -m notenest.main
