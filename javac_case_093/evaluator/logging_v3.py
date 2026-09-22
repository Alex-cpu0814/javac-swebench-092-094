#!/usr/bin/env python3
"""Small Python 3.5-compatible structured logging helpers."""

from __future__ import print_function

import datetime
import json
from pathlib import Path
import sys
import uuid


SCHEMA_VERSION = "3.0"
LEVEL_ORDER = {"DEBUG": 10, "INFO": 20, "WARN": 30, "ERROR": 40}


def utc_now():
    now = datetime.datetime.utcnow()
    return now.strftime("%Y-%m-%dT%H:%M:%S.") + ("%06d" % now.microsecond)[:3] + "Z"


def new_identifier(prefix):
    stamp = datetime.datetime.utcnow().strftime("%Y%m%dT%H%M%SZ")
    return "{}-{}-{}".format(prefix, stamp, uuid.uuid4().hex[:8])


def write_text(path, content):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        handle.write(content)


def write_json(path, value):
    write_text(path, json.dumps(value, indent=2, ensure_ascii=False) + "\n")


def decode_output(value):
    if value is None:
        return ""
    return value.decode("utf-8", "replace") if isinstance(value, bytes) else value


class EventLogger(object):
    """Append JSONL events while keeping console output concise."""

    def __init__(self, path, operation_id, console_level="INFO"):
        self.path = path
        self.operation_id = operation_id
        self.console_level = console_level.upper()
        if self.console_level not in LEVEL_ORDER:
            raise ValueError("Unknown console log level: {}".format(console_level))
        self.path.parent.mkdir(parents=True, exist_ok=True)

    def emit(self, level, phase, event, message, **fields):
        normalized = level.upper()
        if normalized not in LEVEL_ORDER:
            raise ValueError("Unknown log level: {}".format(level))
        record = {
            "schema_version": SCHEMA_VERSION,
            "timestamp": utc_now(),
            "level": normalized,
            "operation_id": self.operation_id,
            "phase": phase,
            "event": event,
            "message": message,
        }
        record.update(fields)
        with self.path.open("a", encoding="utf-8", newline="\n") as handle:
            handle.write(json.dumps(record, ensure_ascii=False, sort_keys=True) + "\n")
        if LEVEL_ORDER[normalized] >= LEVEL_ORDER[self.console_level]:
            stream = sys.stderr if normalized in ("WARN", "ERROR") else sys.stdout
            print("[{}] [{}] {}".format(normalized, phase, message), file=stream)
