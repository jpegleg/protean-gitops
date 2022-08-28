# protean-gitops
A minimalist shell based GitOps system: no gui, cosign and syft for container SBOM, open ended testing.

Git projects can container a `.protean` file that is designed to include (source) two functions, protean_build and protean_test. The build function is for whatever we want to do in the job, from compiling, to download, infalting, whatever is needed. The build is before artifact step. The artifact step is designed for projects with Dockerfile in the repository root and will automatically save container images and generate signed SBOM for them. After the artifact step, then the protean_test function runs.

## Running and scheduling jobs

The proteus script that is installed to /usr/local/sbin/proteus by install.sh can be called, taking a single argument for the git repository location. Either ssh or https can be used, local or remote, just like the git command itself.

```
proteus https://github.com/jpegleg/mihno
```
If there is no local copy of a target repo in /opt/protean-gitops/ then proteus will clone and execute the pipeline. If a local copy already exists, proteus will do a `pull` and only build if there are changes.

The general design pattern with protean-gitops is to use a seprate job scheduling service such as anacron or cron. Here is an example crontab to poll two repositories each minute:

```
* * * * * /usr/local/sbin/proteus ssh://somerepoplace.local/mythings
* * * * * /usr/local/sbin/proteus https://github.com/jpegleg/mihno
```

#### Writing .protean file functions

Here is an example `.protean` file for mihno, a rust honeypot.

```

protean_build() {
  rustup update
  cargo build --release
}

protean_test() {
  cargo test
  cargo clean
}

```

While this .protean example is focused on the rust compiler, we could do whatever we needed to do in these functions, they are truly open ended.

Include the `.protean` file in the root of the git repository targeted by proteus.


### Why cli and not something standard like Jenkins or a cloud service?

In many cases, we won't get the opportunity to use something like protean-gitops and will need to work with something like jenkins, gitlab, etc. However standard and feature rich, those systems have a much larger attack surface. If we have the opportunity to avoid GUIs and large platforms, we can via tools like this. We can create a much tighter pipeline that doesn't need any ports exposed to run, although we can expose a system running protean-gitops with ssh, or whatever else we like. Jenkins often requires constant patching and potentially complicated maintenance and configuration. If we don't need all those features, we can avoid much of the operational costs and risks with a more simple system.

We might even integrate protean-gitops with Jenkins, although that seems funny, it works fine. Rather than scehduling with anacron, we can schedule with something like Jenkins, have it poll SCM directly to the target repo, but then utilize proteus directly or functions taken from it in the other pipeline system.

#### Modularity and simplicity

We can add and expand on protean-gitops easily, it is very flexiable by design. If we want to bake in custom code, no problem. If we want to add a database, PKI, WUI, we can integrate and expand to whatever else is needed.

I am enjoying including Kubernetes and Ansible intergrations in my .protean files, executing deployments in the protean_test function if the tests passed.

### Cleaning up

There is an included script called `cleaner_1.sh` that is installed with install.sh to /usr/local/sbin/cleaner_1.sh. This script will remove files in /opt/protean-gitops/ ending in .log that are less than 1 kilobyte and remove them. This cleaner is not scheduled or used automatically, you will need to determine how you will want to clean up files. When a proteus polling is completed but there were not changes to the git repo, a log file is created states there were no changes. The cleaner_1.sh script removes these "non-event" log files.

Here is an example approach with cron:

```
2-56 * * * * /usr/local/sbin/proteus https://github.com/jpegleg/mihno
2-56 * * * * sleep 20 && /usr/local/sbin/proteus https://github.com/jpegleg/salsa_falcon
58 * * * * /usr/local/sbin/cleaner_1.sh
```
This approach leaves the top of the hour and the end of the hour free of jobs and cleans up on the 58th minute of each hour.

As far as cleaning the artifacts and larger logs for real jobs, there may be another process, such as archival, that is desired there. Management of generated data is not included in this repo, that is up to you.
