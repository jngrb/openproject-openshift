# OpenProject 10 for OpenShift 3

An OpenShift template for OpenProject Community Edition Version 10.

## Installation

### 0 Preparations

Clone this repository and open a terminal in the sandbox.

```[bash]
git clone https://github.com/jngrb/openproject-openshift.git
cd openproject-openshift
```

Login into OpenShift `oc login ...`.

Create an OpenShift project for OpenProject.

```[bash]
PROJECT=openproject
oc new-project $PROJECT
```

### 1a Deploy Database

We use the default persistent PostgreSQL app provided by OpenShift.

```[bash]
oc -n openshift process postgresql-persistent -p POSTGRESQL_USER=openproject -p POSTGRESQL_PASSWORD=openproject -p POSTGRESQL_DATABASE=openproject | oc -n $PROJECT create -f -
```

### 1b Deploy memcached container

We use the MemcacheD app provided by Red Hat's Software Collections.

```[bash]
oc process -f https://raw.githubusercontent.com/sclorg/memcached/master/openshift-template.yml | oc -n $PROJECT create -f -
oc expose dc memcached --port 11211
```

If the OpenProject pod is to be deployed only on selected nodes, apply the node selector also to the Memcached deployment (here, we use the node selector 'appclass=main').

### 2 Deploy OpenProject Initializer

For initialization, the OpenProject container must run as root. Hence, enable this feature for the projects default service account:

```[bash]
oc project $PROJECT
oc create sa root-allowed
oc policy add-role-to-user system:deployer -z root-allowed
oc adm policy add-scc-to-user anyuid -z root-allowed
```

Now, we can run the all-in-one community image for initialization (Change `<POSTGRESQL-PASSWORD>` to the password in the secrets of the postgresql deploment.).

```[bash]
oc process -f https://raw.githubusercontent.com/jngrb/openproject-openshift/master/openproject-initial.yaml -p OPENPROJECT_HOST=openproject-initial.example.com -p DATABASE_URL=postgres://openproject:<POSTGRESQL-PASSWORD>@postgresql.openproject.svc:5432/openproject | oc create -f -
```

Wait for the POD to start and run through all initialization steps. This may take a while.

Do the initial login and settings by browsing to `$OPENPROJECT_HOST`.

* Login with account 'admin' and password 'admin' and change the initial password.
* Try to login with the newly chosen password it should work.
* To persistence of the data, try a reployment of the DB and the OpenProject container and check that you can still login.

Stop the initial container and remove the root-privilege again.

```[bash]
oc rollout pause dc openproject-initial
oc delete pod -l app=openproject-initial
oc adm policy remove-scc-from-user anyuid -z root-allowed
```

### 3 Change permissions for persistent storage volume

As the persistent storage volume was filed with root permissions, you need to prepare the volume to be accessible (especially writable) for any OpenShift serviceaccount.

Currently, you need to do this manually. Assuming that the storage was manually mounted to `/mnt/openproject-data` on any of the cluster nodes, run the following commands as an admin user that is allowed to run `sudo` on the cluster:

```[bash]
cd /mnt/openproject-data
sudo chgroup -R 0 assets
sudo chmod -R g+w assets
```

### 4 Deploy Final OpenProject Application

When the initialization of the files and database is done, we can run the 'real' OpenShift deployment for OpenProject.

```[bash]
oc process -f https://raw.githubusercontent.com/jngrb/openproject-openshift/master/openproject.yaml -p OPENPROJECT_HOST=openproject.example.com -p DATABASE_URL=postgres://openproject:<POSTGRESQL-PASSWORD>@postgresql.openproject.svc:5432/openproject | oc create -f -
```

Finally, you can remove the initializer deployment. It is no longer needed.

```[bash]
oc delete dc community-initial
oc delete sa root-allowed
```

### 5 Settings for HTTPS

* Change the router to edge terminated HTTPS.
* Login as OpenProject administrator and change the hostname to the OpenShift routers address (`$OPENPROJECT_HOST`) and switch the 'Protocol' setting to 'HTTPS'.

### 6 Change the number of replica

Scale the deployment to the number of replicas required for your use case.

```[bash]
oc scale dc community --replicas=<REGULAR_NO_OF_REPLICA>
```

## Upgrades

### Manual upgrade

Scale the regular deployment to zero.

```[bash]
export PROJECT=openproject
export NEW_COMMUNITY_IMAGE_TAG=10.5
export POSTGRESQL_PASSWORD=...
oc project $PROJECT
oc scale dc community --replicas=0
```

Then, modify the image stream to include the new tag and run the upgrade job:

```[bash]
oc process -f https://raw.githubusercontent.com/jngrb/openproject-openshift/master/upgrade/openproject-upgrade-stream.yaml -p COMMUNITY_IMAGE_TAG=$NEW_COMMUNITY_IMAGE_TAG | oc apply -f -
oc process -f https://raw.githubusercontent.com/jngrb/openproject-openshift/master/upgrade/openproject-upgrade.yaml -p COMMUNITY_IMAGE_TAG=$NEW_COMMUNITY_IMAGE_TAG -p DATABASE_URL=postgres://openproject:$POSTGRESQL_PASSWORD@postgresql.openproject.svc:5432/openproject | oc create -f -
```

Note that if the password is wrong, the container logs will contain a misleading error:

```
DATABASE UNSUPPORTED ERROR

Database server is not PostgreSql. As OpenProject uses non standard ANSI-SQL for performance optimizations, using a different DBMS will break and is thus prevented.
```

Finally, change the deployment configuration to the image tag and scale the regular deployment back to your required amount.

```[bash]
oc process -f https://raw.githubusercontent.com/jngrb/openproject-openshift/master/openproject.yaml -p COMMUNITY_IMAGE_TAG=$NEW_COMMUNITY_IMAGE_TAG -p OPENPROJECT_HOST=openproject.example.com -p DATABASE_URL=postgres://openproject:$POSTGRESQL_PASSWORD@postgresql.openproject.svc:5432/openproject | oc apply -f -
oc scale dc community --replicas=<REGULAR_NO_OF_REPLICA>
```

Note: if you use a custom fork, see the description below to update the forked image.

## Open issues / ideas

* Automatic upgrades and "maintenance mode" while upgrading (and even for other maintenance tasks)
* Add IMAP server and run a "cron" container as in <https://github.com/opf/openproject/blob/dev/docker-compose.yml> to process mails received from IMAP.
* Add the "seeder" container as in <https://github.com/opf/openproject/blob/dev/docker-compose.yml> to allow database upgrades/migrations.
* Can we use the Passenger Openshift template from Red Hat's Software Collections, see <https://github.com/sclorg/passenger-container>?
* Or should we use "USE_PUMA=true"?
* How can we migitate a lot of the "problems" arising from the no-root-permissions policy on an OpenShift cluster?

## Dependency on OpenProject Community Edition

This OpenShift template uses software provided by the OpenProject team, specially the official OpenProject docker image (see references below).

These components are licenced under GPL-3.0 with their copyright belonging to the OpenProject team. Also the OpenProject trademark and logo belong to OpenProject GmbH and/or OpenProject Foundation eV.

References:

* <https://docs.openproject.org/installation-and-operations/installation/>
* <https://github.com/opf/openproject>
* <https://hub.docker.com/r/openproject/community>
* <http://www.gnu.org/licenses/gpl-3.0.html>

### Using a custom fork

Create a secret with the access token to the fork repository.

```[bash]
oc project $PROJECT
oc create secret generic <secret_name> \
  --from-literal=username=<user> \
  --from-literal=password=<token> \
  --type=kubernetes.io/basic-auth
```

Then, create a build configuration that builds the basic OpenProject image from the fork repository:

```[bash]
oc process \
  -f https://raw.githubusercontent.com/jngrb/openproject-openshift/master/openproject-build-fork.yaml \
  -p COMMUNITY_IMAGE_TAG=10-noupload \
  -p OPENPROJECT_FORK_REPO=https://gitlab.com/ingenieure-ohne-grenzen/openproject.git \
  -p GIT_BRANCH=stable/10-noupload \
  -p GIT_ACCESS_TOKEN_SECRET=<secret_name> | \
  oc create -f -
```

Next, we can re-deploy the community POD with the fork-based image:

```[bash]
oc process
  -f https://raw.githubusercontent.com/jngrb/openproject-openshift/master/openproject.yaml \
  -p OPENPROJECT_HOST=openproject.example.com \
  -p DATABASE_URL=postgres://openproject:<POSTGRESQL-PASSWORD>@postgresql.openproject.svc:5432/openproject \
  -p COMMUNITY_IMAGE_NAME=community-fork \
  -p COMMUNITY_IMAGE_TAG=10-noupload | \
  oc apply -f -
oc start-build community-app
```

#### Upgrading the forked image

For a new minor release, merge the forked git branch with upstream and push into the forked repo. Now, rerung the build jobs:

```[bash]
oc start-build community-fork # needs 25 minutes to build on our cluster
oc start-build community-app # only after the community-fork build completed successfully
```

## License for the OpenShift template

For compatibility with the OpenProject software components, that this template depends on, this work is published under a very similar and compatible license, the AGPL-3.0.

Copyright (C) 2020, Jan Grieb

> This program is free software: you can redistribute it and/or modify
> it under the terms of the GNU Affero General Public License as published by
> the Free Software Foundation, either version 3 of the License, or
> (at your option) any later version.
>
> This program is distributed in the hope that it will be useful,
> but WITHOUT ANY WARRANTY; without even the implied warranty of
> MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
> GNU Affero General Public License for more details.
>
> You should have received a copy of the GNU Affero General Public License
> along with this program.  The license is location in the file `LICENSE`
> in this repository. Also, see the public document on
> <http://www.gnu.org/licenses/>.

## Contributions

Very welcome!

1. Fork it (https://github.com/jngrb/openproject-openshift/fork)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
