# protean-gitops
A minimalist shell based GitOps system: no gui, cosign and syft for container SBOM, open ended testing.

Git projects can container a `.protean` file that is designed to include (source) two functions, protean_build and protean_test. The build function is for whatever we want to do in the job, from compiling, to download, infalting, whatever is needed. The build is before artifact step. The artifact step is designed for projects with Dockerfile in the repository root and will automatically save container images and generate signed SBOM for them. After the artifact step, then the protean_test function runs. The test function can be treated as a pipeline for testing and deployments.

<b>Note that the `.protean` file can do anything by default, so a git project has effective root code execution on the system running proteus pointed at that project. Sandbox and limit the system that runs proteus, and more importantly, ensure the git repository is well secured. Also, the sourcing of the `.protean` file can be easily removed from proteus, however then all functionality must be included in proteus directly, etc.</b>

## Proteus local Docker registry

The default functionality of proteus expects a local Docker registry on port 5000 which it will use with cosign. The registry can be changed, or proteus can also be used without Docker or without default Docker functions. The majority of the functionality comes from a project's specific `.protean` file, however proteus has some default artifact generation for projects with a Dockerfile in the project root.
Projects with a Dockerfile in the git root will get a container build and insert into localhost:5000, along with SBOM creation and signing with cosign. 

Install Docker before installing protean-gitops to leverage the default functionality. If no registry is running locally, the install.sh will attempt to run one, like this:

```
docker run -d -it --restart unless-stopped -p 5000:5000 registry
```

If you are not going to use Dockerfiles or the default docker artifact generation in protean-gitops, you don't have to. The `.protean` file can do whatever is needed, such as custom container or package builds, deployments, etc.


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
  trivy image "localhost:5000/mihno:test" > ../mihno_trivy-report_$(date +%Y%m%d%H%M%S).txt
}

```

While this .protean example is focused on the rust compiler, we could do whatever we needed to do in these functions, they are truly open ended.

Include the `.protean` file in the root of the git repository targeted by proteus.

If we were going to add an ansible job to deploy the compiled binary, it might look like this:


```

protean_build() {
  rustup update
  cargo build --release
}

protean_test() {
  cargo test
  cargo clean
  trivy image "localhost:5000/mihno:test" > ../mihno_trivy-report_$(date +%Y%m%d%H%M%S).txt
  ansible-playbook -u root -i ../hosts.ini ../deploy_mihno.yml
}

```

Or perhaps a Kubernetes deployment instead:


```

protean_build() {
  rustup update
  cargo build --release
}

protean_test() {
  cargo test
  cargo clean
  trivy image "localhost:5000/mihno:test" > ../mihno_trivy-report_$(date +%Y%m%d%H%M%S).txt
  bash ../insert_update || exit 1
  kubectl apply -f ../mihno-manifest-dev.yml || exit 1
  bash ../test_dev || exit 1
  kubectl apply -f ../mihno-manifest-prod.yml 
}

```

The `bash ../insert_update` is to publish the container image to the needed registry that that Kubernetes cluster uses. Then after that, we apply the dev environment change, then run some tests with `bash ../test_dev` in this case, and if that succeeds without issue, then we apply the change to production automatically.

Instead of having ../insert_update and ../test_dev, those could be contained within the protean_test function as well. I tend to move stuff out of the protean functions if they contain any sort of sensitive information.

### Why cli and not something standard like Jenkins or a cloud service?

In many cases, we won't get the opportunity to use something like protean-gitops and will need to work with something like jenkins, gitlab, etc. However standard and feature rich, those systems have a much larger attack surface. If we have the opportunity to avoid GUIs and large platforms, we can via tools like this. We can create a much tighter pipeline that doesn't need any ports exposed to run, although we can expose a system running protean-gitops with ssh, or whatever else we like. Jenkins often requires constant patching and potentially complicated maintenance and configuration. If we don't need all those features, we can avoid much of the operational costs and risks with a more simple system.

We might even integrate protean-gitops with Jenkins, although that seems funny, it works fine. Rather than scheduling with anacron, we can schedule with something like Jenkins, have it poll SCM directly to the target repo, but then utilize proteus directly or functions taken from it in the other pipeline system.

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
