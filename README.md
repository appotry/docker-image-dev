## Docker images for Vespa development

This repo contains Docker images for Vespa development on AlmaLinux 8 (Vespa 8).
[vespa-build-almalinux-8](https://hub.docker.com/repository/docker/vespaengine/vespa-build-almalinux-8)
is used for only building Vespa, while
[vespa-dev-almalinux-8](https://hub.docker.com/repository/docker/vespaengine/vespa-dev-almalinux-8)
is used for active development of Vespa with building, unit testing and running of system tests.
vespa-dev-almalinux-8 depends on vespa-build-almalinux-8. To pull the images:

    docker pull docker.io/vespaengine/vespa-build-almalinux-8:latest
    docker pull docker.io/vespaengine/vespa-dev-almalinux-8:latest

Commits to master will automatically trigger new builds and deployment on Docker Hub.

Read more at the Vespa project [homepage](http://docs.vespa.ai).

The project is covered by the [Apache License, Version 2.0](https://www.apache.org/licenses/LICENSE-2.0).


## Vespa development on AlmaLinux 8

This guide describes how to build, unit test and system test Vespa on AlmaLinux 8 using Docker or Podman.
Change from `docker` to `podman` in the commands below if using Podman.

When doing Vespa development it is important that the turnaround time between code changes
and running unit tests and system tests is short.
[vespa-dev-almalinux-8](https://hub.docker.com/repository/docker/vespaengine/vespa-dev-almalinux-8)
provides a complete environment for this.
The code is compiled using mvn, cmake and make and then installed into your personal install directory.
Vespa can be executed directly from this directory when for instance running system tests.


### Docker configuration

#### Docker on macOS

Make sure Docker has sufficient resources:

Open Docker - Preferences - Resources and set:
* CPUs: Minimum 2. Use 8 or more for faster build times.
* Memory: Minimum 8 GB. 16 GB or more is preferred.
* Disk size: 128 GB.

#### Docker on Linux

Make sure Docker can be executed without sudo for the scripts in this guide to work:

    sudo groupadd docker
    sudo usermod -aG docker $(id -un)
    sudo systemctl restart docker

Log out and login again; or run `sudo su - $USER` command to continue.

#### Podman on macOS

Install Podman Desktop:

    brew install podman-desktop

Create a new Podman Machine with sufficient resources (Preferences - Resources - Create new ...)
* CPUs: Minimum 2. Use 8 or more for faster build times.
* Memory: Minimum 8 GB. 16 GB or more is preferred.
* Disk size: 128 GB.
* Machine with root privileges: Enabled

The Podman Machine can also be created using `podman machine init`:

    podman machine init --cpus=8 --memory=16384 --disk-size=128 --rootful


### Setup the Docker container

#### Download the latest vespa-dev-almalinux-8 Docker image

    docker pull docker.io/vespaengine/vespa-dev-almalinux-8:latest

#### Create the Docker container

##### Remote debugging

If you want to be able to attach a remote debugger (e.g. IntelliJ) to a process inside the container,
you need to add port forwarding at this stage. It cannot be done after the container has been created.
To allow debugging on port 5005, insert the following line in between the lines to the command in the
appropriate section below:

    -p 127.0.0.1:5005:5005 \

##### With explicit Docker volume (recommended for macOS)

First, create a long lived Docker volume.
This lets us persist data generated by and used by the Docker container.
Skip this step if the volume already exists.

    docker volume create volume-vespa-dev-almalinux-8

Second, create the container by mounting the volume as the home directory inside the container:

    docker create \
        -p 127.0.0.1:3334:22 \
        -v volume-vespa-dev-almalinux-8:/home/$(id -un) \
        --privileged \
        --pids-limit -1 \
        --name vespa-dev-almalinux-8 \
        docker.io/vespaengine/vespa-dev-almalinux-8:latest

##### With directory volume mount (recommended for Linux)

A directory on the host machine can be mounted into the container using the -v option.
This lets us persist data generated by and used by the Docker container.
When running Docker on a Linux host there is basically no overhead doing so.
First, create a volume directory on the host:

    mkdir -p $HOME/volumes/vespa-dev-almalinux-8

Second, run docker create with the -v option to mount the volume directory as the home directory in the container:

    docker create \
        -p 127.0.0.1:3334:22 \
        -v $HOME/volumes/vespa-dev-almalinux-8:/home/$(id -un) \
        --privileged \
        --pids-limit -1 \
        --name vespa-dev-almalinux-8 \
        docker.io/vespaengine/vespa-dev-almalinux-8:latest


#### Start the Docker container

    docker start vespa-dev-almalinux-8

#### Configure the Docker container

Ensure you have an SSH key before running the `configure-container.sh` script.
If not, use the following guide
[to generate a new SSH key](https://help.github.com/en/github/authenticating-to-github/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent).

    mkdir -p $HOME/git
    cd $HOME/git
    git clone https://github.com/vespa-engine/docker-image-dev.git
    cd $HOME/git/docker-image-dev/dev/almalinux-8

If using Docker:

    ./configure-container.sh docker vespa-dev-almalinux-8

Or, if using Podman:

    ./configure-container.sh podman vespa-dev-almalinux-8

This adds yourself as user in the container, copies authorized keys to ensure ssh can be used,
and sets environment variables needed for building Vespa.

#### Build the vespa-dev-almalinux-8 Docker image (optional)

    cd $HOME/git/docker-image-dev/dev/almalinux-8
    docker build -t vespaengine/vespa-dev-almalinux-8:latest .

Use this for testing if doing changes to the Docker image.


### Build Vespa

#### SSH into the container

    ssh -A 127.0.0.1 -p 3334

If the ssh command fails, see [SSH troubleshooting](#ssh-troubleshooting)


#### Checkout Vespa repo

    mkdir -p $HOME/git
    cd $HOME/git
    git clone git@github.com:vespa-engine/vespa.git
    cd $HOME/git/vespa

#### Clean up old state (if using a long lived docker volume)

If you are persisting data from a previous container, clean out old state to ensure that the latest version
of build tools will be used:

    git clean -fdx
    ccache --clear

#### Build Java modules

    ./bootstrap.sh java
    ./mvnw clean install --threads 1C -Dmaven.javadoc.skip=true -Dmaven.source.skip=true -DskipTests

#### Build C++ modules

    cd $HOME/git/vespa
    cmake3 .
    make -j 9

Set the number of compilation threads (-j argument) to the number of CPU cores + 1.

##### Build and optimize for newer cpu architectures

You can use the compiler flags `-march=` and `-mtune=` to specify the CPU generation to build for. For details and options consult the
[GCC manual](https://gcc.gnu.org/onlinedocs/gcc/x86-Options.html#x86-Options).
The below command will setup building with the instruction set available on the Intel Haswell CPU generation
and optimize code generation for the even newer Intel Icelake CPU generation,
but still use only the instruction set available on Haswell.

    cmake3 -DVESPA_CPU_ARCH_FLAGS="-march=haswell -mtune=skylake" .

#### Install modules

    make install/fast

Default install directory is $HOME/vespa ($VESPA_HOME).


### Run unit tests

#### Test all Java modules

    mvn test --threads 1C

#### Test specific Java module (e.g. container-search)

    mvn test --threads 1C -pl container-search

#### Test all C++ modules

    ctest -j 9

#### Test specific C++ module (e.g. searchlib)

    ctest -j 9 -R "^searchlib_"


### Run system tests

#### Checkout system-test repo

    cd $HOME/git
    git clone https://github.com/vespa-engine/system-test.git

Note that the system test scrips are already in your PATH inside the Docker container.

#### Copy feature flag overrides from system test repo

Some system tests depend on feature flag overrides.

    cp $HOME/git/system-test/docker/include/feature-flags.json $HOME/vespa/var/vespa/flag.db

#### Start nodeserver in one terminal

    nodeserver.sh

#### Run system test in another terminal

    runtest.sh $HOME/git/system-test/tests/search/basicsearch/basic_search.rb

### Building and running Vespa with sanitizer instrumentation

Vespa natively supports building and running C++ code instrumented using [sanitizers](https://github.com/google/sanitizers).

#### Building C++ code with sanitizers

Pass the `VESPA_USE_SANITIZER=sanitizer` variable to CMake, where `sanitizer`
must be one of the following:

* `address` - instrument using [AddressSanitizer](https://github.com/google/sanitizers/wiki/AddressSanitizer)
* `thread` - instrument using [ThreadSanitizer](https://github.com/google/sanitizers/wiki/ThreadSanitizerCppManual)
* `undefined` - instrument using [UndefinedBehaviorSanitizer](https://clang.llvm.org/docs/UndefinedBehaviorSanitizer.html)
* `address,undefined` instrument using both AddressSanitizer and UndefinedBehaviorSanitizer.
  This is the only supported option for using multiple sanitizers at the same time.

Example for generating build-files that instrument Vespa using ThreadSanitizer:

```
cmake3 -DVESPA_USE_SANITIZER=thread .
```

Note that vespamalloc is not built when sanitizers are configured, as both vespamalloc
and sanitizers will attempt to intercept/override default libc malloc API calls.

#### Running instrumented unit tests

Unit tests can be run as usual, both directly from the terminal and from within CLion.

If a test is flaky (especially if it involves a rare race condition), it's often useful
to be able to run one particular test in a loop until it fails. Both GTest and the sanitizers
can be easily configured using environment variables.

Example environment variables for running a single test case 100 times, immediately aborting
if either the test fails or ThreadSanitizer detects a problem (here presented in CLion run
configuration format):

```
GTEST_FILTER=MyFlakyTestSuite.my_flaky_test_case;GTEST_REPEAT=100;TSAN_OPTIONS=halt_on_error=1;GTEST_FAIL_FAST=1
```

When setting your own `TSAN_OPTIONS` environment variable you may have to manually add the
`suppressions` option and point it to the [tsan-suppressions.txt](https://github.com/vespa-engine/vespa/blob/master/tsan-suppressions.txt)
file found in the Vespa source code root directory to avoid getting reports for already known false positives.
This option is automatically set when running unit tests via CTest.

Note that you cannot run an instrumented unit test under Valgrind.

#### Running instrumented system tests

As with unit tests, system tests can be run as usual with no extra setup needed.
However, since system tests run with many instrumented processes simultaneously, it's
useful to configure sanitizers to emit per-process error logs and to suppress known,
benign warnings.

Processes are launched in the context of the system test node server, so export
any environment variables prior to launching it.

Example (substitute paths with your own):

```
export TSAN_OPTIONS="suppressions=/home/myuser/git/vespa/tsan-suppressions.txt log_path=/home/myuser/tsan_logs/log history_size=7 detect_deadlocks=1 second_deadlock_stack=1"
nodeserver.sh
```

##### Troubleshooting

If processes emit fatal sanitizer warnings on startup, e.g:

```
==51385==FATAL: ThreadSanitizer: failed to intercept munmap
```

then this is usually a sign that there are traces of a previous (non-instrumented) vespamalloc
build in your Vespa install tree. Vespa startup scripts will implicitly pick up and load
vespamalloc if it's present, regardless of instrumentation status. The easiest way to get
around this is to wipe the install tree and re-run `make install`.

### Use CLion or IntelliJ natively in the development container via JetBrains Gateway

Recent versions of the JetBrains IDEs natively support _remote development_, where
the IDE frontend runs on the native OS, while the compilation and analysis backend
runs on a remote host (or in our case, a local Podman container). This works out of
the box for both macOS and Linux as the frontend OS.

Note that remote development is not supported on the IntelliJ IDEA Community edition.

#### Use the JetBrains Toolbox app to install IDEs

The easiest way to manage (and update) multiple installed IDEs is via the
[JetBrains Toolbox app](https://www.jetbrains.com/toolbox-app/).

Via the Toolbox, install and launch the desired IDE application(s).

#### Set up Remote Development mode

 1. Launch the desired IDE from the Toolbox
 2. Navigate to `Remote Development` --> `SSH`.
 3. Set up a new connection. Specify your username and the host/port configured
    earlier when setting up the Podman container (by default 127.0.0.1 and 3334).
    It is recommended to use an SSH agent (for instance via 1Password) to manage
    SSH private keys, as this streamlines the SSH authentication process considerably.
 4. Once the connection is established, add a new project. Specify the IDE version
    (generally the latest, non-early access build is preferred) and the root directory
    of the project (e.g. `/home/<username>/git/vespa`).
 5. Launch the IDE from the `Recent SSH Projects` view. The IDE should now be usable
    as if it were natively running on the host OS.

### Use CLion or IntelliJ via X11 forwarding

This is an alternative approach to developing remotely, which uses X11 forwarding
over SSH instead of having the IDE split into distinct frontend and backend parts.
It therefore also works with the IntelliJ IDEA Community edition.

This is expected to work natively on Linux, though empirical observations indicate
that Wayland-based compositors may experience performance regressions over X11-based
compositors.

macOS does not have native X11 capabilities, so a dedicated program (XQuartz) must
be used.

#### macOS specific: install XQuartz
XQuartz is a version of the X.Org X Window System for macOS. Download
[here](https://www.xquartz.org/).

#### Configure sshd inside container to use ipv4
Set ```AddressFamily inet``` inside ```/etc/ssh/sshd_config``` and restart sshd:

    sudo kill -HUP <sshd-pid>

#### SSH into container with X11 forwarding
Open a terminal (for macOS, this must be an XQuartz terminal) and run:

    ssh -Y -A 127.0.0.1 -p 3334

Then start CLion or IntelliJ from this terminal.


### SSH troubleshooting

If the ssh command fails, e.g. with the following message:

`ssh kex_exchange_identification: Connection closed by remote host`

then, execute an interactive shell on the container:

    docker exec -it vespa-dev-almalinux-8 /bin/bash

Inside the shell, check if there are any host keys:

    ls -l /etc/ssh

If the folder does not contain any `ssh_host_*` files, use this command to generate host keys:

    sudo ssh-keygen -A

Then, start the ssh daemon:

    $(which sshd)

If you need to debug further, add the flags `-Ddp` to the above command. In another terminal, try to ssh
into the container again with the appropriate level of verbosity, e.g.

    ssh -vvv -A 127.0.0.1 -p 3334

### CLion 2024.3 configuration (MacOS client)

*   CLion | Settings
    *   Build, Execution, Deployment | Toolchains
        *   CMake: /usr/bin/cmake
        *   Build Tools: /usr/bin/make
        *   Debugger: /opt/rh/gcc-toolset-14/root/usr/bin/gdb
    *   Advanced Settings (Host)
        *   Automatically import CMake Presets: None
*   File | New project setup | Settings for new projects
    *   Editor | Code Style
        *   CMake
            *   continuation indent: 4
        *   C++
            *   continuous line indent: Single
            *   Indent namespace members: Do not indent
    *   Build, Execution, Deployment
        *   CMake
            *   Cmake profile: Default (add new ones until Default appears, and disable all other profiles).
            *   Cmake build directory: .
        *   Build Tools | Make
            *   Path to make executable: /usr/bin/make

### CLion 2024.3 configuration (Linux client)

*   File | Settings
    *   Build, Execution, Deployment | Toolchains
        *   CMake: /usr/bin/cmake
        *   Build Tools: /usr/bin/make
        *   Debugger: /opt/rh/gcc-toolset-14/root/usr/bin/gdb
    *   Advanced Settings (Host)
        *   Automatically import CMake Presets: None
*   File | New project setup | Settings for new projects
    *   Editor | Code Style
        *   CMake
            *   continuation indent: 4
        *   C++
            *   continuation indent: Single
            *   Indent members of namespace: Do not indent
    *   Build, Execution, Deployment
        *   CMake
            *   Cmake profile: Default (add new ones until Default appears, and disable all other profiles).
            *   Cmake build directory: .
        *   Build Tools | Make
            *   Path to make executable: /usr/bin/make

### Environment variable tuning to avoid excessive ccache miss rate

The following environment variables are checked by ccache: `GCC_COLORS`, `LANG`, `LC_ALL`, `LC_CTYPE` and `LC_MESSAGES`

The `CMAKE_COLOR_DIAGNOSTICS` environment variable affects how CMake generates makefiles and what arguments are passed to
compiler, thus indirectly affecting caching.

If compilation on command line uses different settings for the above environment variables than what CLion is using then
the ccache miss rate will be higher. CLion sets `CMAKE_COLOR_DIAGNOSTICS` and `GCC_COLORS` internally, thus shell startup
files should also set them to the same values.

Adjust `.bashrc` to ensure that the relevant environment variables are always set, also for non-interative shells, e.g.
```
if [[ "$SHLVL" < 2 ]]; then
    export CMAKE_COLOR_DIAGNOSTICS=ON
    export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'
    export LANG=en_US.UTF-8
    export LC_CTYPE=en_US.UTF-8
fi
```

Note that emacs also need some tuning to handle colors in output. A web search for
```
emacs compilation buffer ansi colors
```
might provide some hints about how to adjust the emacs configuration.
