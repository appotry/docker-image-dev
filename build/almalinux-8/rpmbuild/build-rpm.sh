#!/bin/sh
# Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root.

cd $(cd $(dirname $0) && env pwd)

. ../../../shared-rpmbuild/build-rpm-common.sh

DOCKER_IMAGE=almalinux:8
CONTAINER_SHORTNAME=a8

build_rpm_common "$@"
