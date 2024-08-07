<!--- Copyright Vespa.ai. Licensed under the terms of the Apache 2.0 license. See LICENSE in the project root. --->
## Running vespa system tests using docker swarm

Initialize docker swarm if not already initialized

    docker swarm init

It might be necessary to use the `--default-address-pool` option to
avoid conflict with addresses on the local network, e.g.

    docker swarm init --default-addr-pool 10.2.0.0/15

Specify that current node can run vespanode service tasks.

On Linux hosts:

    docker node update --label-add enable-$USER-vespanode=true $(hostname)

On MacOS when using docker for mac:

    docker node update --label-add enable-$USER-vespanode=true docker-desktop

Swarm nodes without the label will not run the vespanode service task
when the service constraint require the label to be present. Most of
the time, only the same host that contains the development environment should
have the label set, to simplify small scale tests while still keeping the
host as part of an existing docker swarm.

Build baseline base image:

    cd $HOME/git/docker-image-dev/docker-swarm/almalinux-8
    ./build-vespanode-baselinebase.sh


Compile and install vespa in development environment. See [build documentation](../../README.md) for details.

Build vespanode image on top on baseline base image (assuming that development environment home directory is on named volume volume-vespa-dev-almalinux-8):

    ./build-vespanode.sh

or build a vespanode baseline image before building the vespanode image:

    ./build-vespanode.sh -m baseline
    ./build-vespanode.sh -m fixup

If the changes between each test iteration is small, rebuilding the vespanode image on top of a longer lived vespanode baseline image is faster, e.g. a few seconds.

### Multi node setup

Enable selected swarm nodes:

    ./enable-vespanode-host.sh <hostname>

Disable selected swarm nodes:

    ./disable-vespanode-host.sh <hostname>

List what nodes are used for testing:

    ./list-vespanode-hosts.sh

Host name specified above must match one of the host names shown in the
output of

    docker node ls

#### Distributing system test images to multiple nodes

If vespanode service task has been enabled on multiple swarm nodes then the
vespanode image should be distributed to those nodes. The method described
below should be adapted to use a secure docker registry when used in an
environment where hardening is required.

Ensure that all relevant swarm nodes have checked out this repository at
$HOME/git/docker-image-dev.

Start an unsecure local docker registry

    ./run-vespanode-registry.sh

Distribute the baseline base image

    make distribute-vespanode-baselinebase

Distribute the baseline image

    make distribute-vespanode-baseline

Distribute the test image:

    make distribute-vespanode


### Running system tests
Run basic search system test on swarm:

    ./run-basic-search-test.sh

Run resize tests on swarm (Assumes multiple hosts or a host with 64 GB memory):

    ./run-resize-tests.sh

Run all tests on swarm (Assumes multiple hosts or a host with 256 GB memory):

    ./run-all-tests.sh

### Developing multi node system test

Create a shell script for running your multi node system test with proper parameters.

1. In the development evironment:
    1. clean out the vespa install directory
    2. reinstall the modified version of vespa
2. On the host:
    1. Build vespanode image.
    2. Distribute vespanode image to nodes where vespanode service task has been enabled (can be skipped when the host for the development environment is the only host where the vespanode service task has been enabled).
    3. Run test using the shell script for running your multi node system test.
    4. Examine test results.

3. In the development evironment:
    1. Make changes to vespa code
    2. Recompile vespa.
    3. reinstall the modified version of vespa
    4. Goto 2.i.
