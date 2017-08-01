This example script provides diagnostic tasks that can be used to gather troubleshooting information from active [Red Hat Middleware containers](https://access.redhat.com/documentation/en/red-hat-jboss-middleware-for-openshift/) for Openshift.

## Prerequisites

- Openshift CLI client - https://docs.openshift.org/latest/cli_reference/get_started_cli.html


## Running

Save the script to a desired location.

~~~
$ xdiag.sh -h
xPaaS Diagnostic Utilities

Must be logged into an Openshift environment to use this script.
Login command example:
oc login https://some-openshift-master:8443/

Usage:
  xdiag.sh [-dh] TASKS -p POD [-o DIRECTORY]

Examples:
  Retrieve a copy of the JBoss standalone-openshift.xml from a running xPaaS container and save the file in the current directory.
  $ xdiag.sh -p some-pod-name -c

  Retrieve the Dockerfiles from a running xPaaS container.
  $ xdiag.sh -p some-pod-name -f

  Get a JBoss JDR report from a running xPaaS container and save the file in the current directory.
  $ xdiag.sh -p some-pod-name -j

  Get a Java heap file from a running xPaaS container and save the file in the /tmp/foo directory.  The output directory must exist.
  $ xdiag.sh -p some-pod-name -m -o /tmp/foo

  Get a Java heap file and a Java thread dump from a running xPaaS container and save the files in the current directory.
  $ xdiag.sh -p some-pod-name -mt

  Get a JBoss JDR report, Java heap file and a Java thread dump from a running xPaaS container and save the files in the current directory.
  $ xdiag.sh -p some-pod-name -jmt


Options:
  -o : Ouput directory.  If omitted, the current directory is used
  -p : Pod name
  -d : Leave generated files in pod container.  Generated files are deleted by default
  -h : help


Tasks:
  -c : Retrieve a copy of the JBoss standalone-openshift.xml from a running xPaaS container
  -f : Retrieve the Dockerfiles from a running xPaaS container
  -j : Get a JBoss JDR report from a running xPaaS container
  -m : Get a Java heap file from a running xPaaS container
  -t : Get a Java thread dump from a running xPaaS container
~~~
