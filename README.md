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
oc project $PROJECT
oc -n openshift process postgresql-persistent -p POSTGRESQL_DATABASE=openproject | oc create -f -
```

(If you want to keep things simple for testing, use -p POSTGRESQL_USER=onlyoffice -p POSTGRESQL_PASSWORD=onlyoffice.)

### 1b Deploy memcached container

We use the MemcacheD app provided by Red Hat's Software Collections.

```[bash]
oc process -f https://raw.githubusercontent.com/sclorg/memcached/master/openshift-template.yml | oc create -f -
oc expose dc memcached --port 11211
```

If the OpenProject pod is to be deployed only on selected nodes, apply the node selector also to the Memcached deployment (here, we use the node selector 'appclass=main'):

```[bash]
oc patch dc memcached --patch='{"spec":{"template":{"spec":{"nodeSelector":{"appclass":"main"}}}}}'
```

Also, the image stream reference must be fixed from the Console WebUI.

### 2 Deploy OpenProject Initializer

For initialization, the OpenProject container must run as root. Hence, enable this feature for the projects default service account:

```[bash]
oc project $PROJECT
oc create sa root-allowed
oc policy add-role-to-user system:deployer -z root-allowed
oc adm policy add-scc-to-user anyuid -z root-allowed
```

For security, the postgres access configuration must be stored in a new secret. The secret of the postgresql deployment cannot be used because the information is in the wrong format.

```[bash]
oc create secret generic openproject-database-secret --type=Opaque \
  --from-literal=DATABASE_URL=postgres://<POSTGRESQL-USER>:<POSTGRESQL-PASSWORD>@postgresql.openproject.svc:5432/openproject
```

Now, we can run the all-in-one community image for initialization (Change `<POSTGRESQL-PASSWORD>` to the password in the secrets of the postgresql deploment.).

```[bash]
export OPENPROJECT_INITIAL_HOST=openproject-initial.example.com
oc process -f https://raw.githubusercontent.com/jngrb/openproject-openshift/master/openproject-initial.yaml -p OPENPROJECT_HOST=$OPENPROJECT_INITIAL_HOST -p DATABASE_SECRET=openproject-database-secret | oc create -f -
```

Wait for the POD to start and run through all initialization steps. This may take a while.

(As of 2020-09-19, the initialization failes with a permission denied. This can be fixed by running "chown -R app:app /app/tmp/cache/DC*" at an early time of the initialization in the terminal.)

Do the initial login and settings by browsing to `$OPENPROJECT_HOST`.

* Login with account 'admin' and password 'admin' and change the initial password.
* Try to login with the newly chosen password it should work.
* To persistence of the data, try a reployment of the DB and the OpenProject container and check that you can still login.

Stop the initial container and remove the root-privilege again.

```[bash]
oc scale dc community-initial --replicas=0
# wait here until the replica count is zero
oc rollout pause dc community-initial
oc delete pod -l app=openproject
oc adm policy remove-scc-from-user anyuid -z root-allowed
```

### 3 Change permissions for persistent storage volume

As the persistent storage volume was filed with root permissions, you need to prepare the volume to be accessible (especially writable) for any OpenShift serviceaccount.

Currently, you need to do this manually. Assuming that the storage was manually mounted to `/mnt/openproject-data` on any of the cluster nodes, run the following commands as an admin user that is allowed to run `sudo` on the cluster:

```[bash]
cd /mnt/openproject-data
sudo chgrp -R 0 assets
sudo chmod -R g+w assets
```

### 4 Deploy Final OpenProject Application

When the initialization of the files and database is done, we can run the 'real' OpenShift deployment for OpenProject.

```[bash]
export OPENPROJECT_HOST=openproject.example.com
oc project $PROJECT
oc process -f https://raw.githubusercontent.com/jngrb/openproject-openshift/master/openproject.yaml -p OPENPROJECT_HOST=$OPENPROJECT_HOST -p DATABASE_SECRET=openproject-database-secret | oc apply -f -
```

After the regular OP container was started, you will have to fix the permissions on the data directory. Mount the PV on a cluster node and run:

```[bash]
sudo chown -R <UID>:0 assets
```

where `<UID>` is the user ID of the service account that runs the OP container.

Finally, you can remove the initializer deployment. It is no longer needed. The service account will again be needed for upgrades.

```[bash]
oc delete dc community-initial
#oc delete sa root-allowed
```

### 5 Settings for HTTPS

Check that you have all checks on `${OPENPROJECT_HOST}/admin/info` except for "IFC conversion pipeline available" (not needed). If "Attachments directory writable" is not yet checked, make sure that the container can write to the attachments persistent volume as described in section "3 Change permissions for persistent storage volume".

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
export POSTGRESQL_USER=...
export POSTGRESQL_PASSWORD=...
oc project $PROJECT
oc scale dc community --replicas=0
```

Then, modify the image stream to include the new tag and run the upgrade job:

```[bash]
oc adm policy add-scc-to-user anyuid -z root-allowed
oc process -f https://raw.githubusercontent.com/jngrb/openproject-openshift/master/upgrade/openproject-upgrade-stream.yaml -p COMMUNITY_IMAGE_TAG=$NEW_COMMUNITY_IMAGE_TAG | oc apply -f -
oc process -f https://raw.githubusercontent.com/jngrb/openproject-openshift/master/upgrade/openproject-upgrade.yaml -p COMMUNITY_IMAGE_TAG=$NEW_COMMUNITY_IMAGE_TAG -p DATABASE_SECRET=openproject-database-secret | oc create -f -
```

Note that if the password is wrong, the container logs will contain a misleading error:

```
DATABASE UNSUPPORTED ERROR

Database server is not PostgreSql. As OpenProject uses non standard ANSI-SQL for performance optimizations, using a different DBMS will break and is thus prevented.
```

(As of 2020-09-19, the upgrade failes with a permission denied. This can be fixed by running "chown -R app:app /app/tmp/cache/DC*" at an early time of the initialization in the terminal.)

Finally, change the deployment configuration to the image tag and scale the regular deployment back to your required amount.

```[bash]
export OPENPROJECT_HOST=openproject.example.com
oc process -f https://raw.githubusercontent.com/jngrb/openproject-openshift/master/openproject.yaml -p COMMUNITY_IMAGE_TAG=$NEW_COMMUNITY_IMAGE_TAG -p OPENPROJECT_HOST=$OPENPROJECT_HOST -p DATABASE_SECRET=openproject-database-secret | oc apply -f -
oc scale dc community --replicas=<REGULAR_NO_OF_REPLICA>
oc adm policy remove-scc-from-user anyuid -z root-allowed
```

After the regular OP container was started, you will have to fix the permissions on the data directory again. Mount the PV and run:

```[bash]
sudo chown -R <UID>:0 assets
```

where `<UID>` is the user ID of the service account that runs the OP container.

Check on page `https://$OPENPROJECT_HOSTadmin/info` that every is OK (all checks).

Note: if you use a custom fork, see the description below to update the forked image.

### Semi-automatic Jenkins update and upgrade

We use an (ephemeral) Jenkins for automatic deployments of configuration updates and image upgrades. First, deploy the Jekins POD:

```[bash]
oc project $PROJECT
oc -n openshift process jenkins-ephemeral | oc create -f -
```

As as the main PODs, you might want to deploy the Jenkins container only on selected nodes. (E.g., you can the same node selector, 'appclass=main'.)

```[bash]
oc patch dc jenkins --patch='{"spec":{"template":{"spec":{"nodeSelector":{"appclass":"main"}}}}}'
```

Note, Jenkins might take a long time to deploy.

#### Update pipeline to reset configuration

After having logged into Jenkins for the first time, you can roll out the JenkinsPipeline build configuration.

```[bash]
oc process -f update-pipeline.yaml -p OPENPROJECT_HOST=$OPENPROJECT_HOST -p COMMUNITY_IMAGE_TAG=11.1 -p DATABASE_SECRET=openproject-database-secret | oc apply -f -
```

Or replace instead use this line if the pipeline is for the "forked image".

```[bash]
oc process -f update-pipeline.yaml -p OPENPROJECT_HOST=$OPENPROJECT_HOST -p BUILD_FORK_IMAGE=true -p COMMUNITY_IMAGE_TAG=10-noupload -p DATABASE_SECRET=openproject-database-secret | oc apply -f -
```

This pipeline updates the deployment configuration to the newest version from the template as checked in on the master branch on Github. Then, it builds the fork and the deployment image.

#### Upgrade pipeline to migrate to new version

For each new version to upgrade to, roll out the JenkinsPipeline upgrade configuration. Either for the regular OpenProject image:

```[bash]
oc process -f upgrade/upgrade-pipeline.yaml -p OPENPROJECT_HOST=$OPENPROJECT_HOST -p NEW_COMMUNITY_IMAGE_TAG=11.1 DATABASE_SECRET=openproject-database-secret | oc apply -f -
```

Or alternatively for a OpenProject image from a fork repository (see below):

```[bash]
export GIT_ACCESS_TOKEN_SECRET=<secret_name>
oc process -f upgrade/upgrade-pipeline.yaml \
  -p OPENPROJECT_HOST=$OPENPROJECT_HOST \
  -p NEW_COMMUNITY_IMAGE_TAG=11.1 \
  -p DOCKER_PATH=./docker/prod \
  -p DATABASE_SECRET=openproject-database-secret -p BUILD_FORK_IMAGE=true \
  -p FORKED_COMMUNITY_IMAGE_TAG=11-noupload \
  -p OPENPROJECT_FORK_REPO=https://gitlab.com/ingenieure-ohne-grenzen/openproject.git \
  -p OPENPROJECT_FORK_GIT_BRANCH=stable/11-noupload-dev \
  -p GIT_ACCESS_TOKEN_SECRET=$GIT_ACCESS_TOKEN_SECRET \
  -p DOCKERFILE_PATH=docker/prod/Dockerfile \
  -p RUBY_IMAGE_TAG=2.7.2-buster | \
  oc apply -f -
```

Before running the upgrade job, there are some manual preparation steps.

```[bash]
oc adm policy add-scc-to-user anyuid -z root-allowed
```

If you want to upgrade to a forked image, also update the fork repo before starting the pipeline job. For a new major release, create a new forked branch from the stable upstream branch and cherry-pick the changes from the old fork into the new branch. For a new minor release, only merge the forked git branch with upstream and push into the forked repo.

```[bash]
cd /path/to/clone/of/fork/repo
git checkout stable/11-noupload
git fetch upstream
git merge upstream/stable/11
git push
```

Now run the pipeline job for the upgrade. After the upgrade job completed, the following cleanup tasks are necessary:

```[bash]
oc adm policy remove-scc-from-user anyuid -z root-allowed
```

After the upgraded OP container was started, you will have to fix the permissions on the data directory again. Mount the PV and run:

```[bash]
sudo chown -R <UID>:0 assets
```

### Single-Sign-On using an Apache-OpenID-Connect proxy

We need a "wrapping" Apache reverse-proxy with mod_auth_openidc to get Single-Sign-On working in OpenProject.

We assume that a client `apache-odic-for-openproject` is registered at the OpenID-Connect provider (e.g. Keycloak) and that the acces type is 'confidential'. We must add the value for `OPENPROJECT_AUTH__SOURCE__SSO_SECRET` and the client secret to the secrets store:

```[bash]
oc project $PROJECT
oc create secret generic sso-auth-source-secret \
  --from-literal=OIDC_CLIENT_SECRET=<OIDC client secret> \
  --from-literal=OPENPROJECT_AUTH__SOURCE__SSO_SECRET=<randomstring> \
  --type=Opaque
```

Now, we add the build and deployment configuration for the Apache-OIDC-Proxy:

```[bash]
oc project $PROJECT
oc process -f apache-openidc/apache-oidc-proxy.yml
  -p PUBLIC_OPENPROJECT_HOST=openproject.apps.ingenieure.cloud
  -p OIDC_METADATA_URL=https://keycloak.apps.ingenieure.cloud/auth/realms/master/.well-known/openid-configuration | \
  oc apply -f -
```

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
export GIT_ACCESS_TOKEN_SECRET=<secret_name>
oc process \
  -f https://raw.githubusercontent.com/jngrb/openproject-openshift/master/openproject-build-fork.yaml \
  -p COMMUNITY_IMAGE_TAG=10-noupload \
  -p OPENPROJECT_FORK_REPO=https://gitlab.com/ingenieure-ohne-grenzen/openproject.git \
  -p GIT_BRANCH=stable/10-noupload \
  -p GIT_ACCESS_TOKEN_SECRET=$GIT_ACCESS_TOKEN_SECRET \
  -p RUBY_IMAGE_TAG=2.6-stretch | \
  oc apply -f -
```

Next, we can re-deploy the community POD with the fork-based image:

```[bash]
export OPENPROJECT_HOST=openproject.example.com
oc process \
  -f https://raw.githubusercontent.com/jngrb/openproject-openshift/master/openproject.yaml \
  -p OPENPROJECT_HOST=$OPENPROJECT_HOST \
  -p DATABASE_SECRET=openproject-database-secret \
  -p COMMUNITY_IMAGE_KIND=ImageStreamTag \
  -p COMMUNITY_IMAGE_NAME=community-fork \
  -p COMMUNITY_IMAGE_TAG=10-noupload | \
  oc apply -f -
oc start-build community-app
```

#### Upgrading the forked image

For a new major release, create a new forked branch (here 11-noupload) from the stable upstream branch and cherry-pick the changes from the old fork into the new branch. Then, update the major version in the fork build job and the deployment config:

```[bash]
export OPENPROJECT_HOST=openproject.example.com
export GIT_ACCESS_TOKEN_SECRET=<secret_name>
oc process \
  -f https://raw.githubusercontent.com/jngrb/openproject-openshift/master/openproject-build-fork.yaml \
  -p COMMUNITY_IMAGE_TAG=11-noupload \
  -p OPENPROJECT_FORK_REPO=https://gitlab.com/ingenieure-ohne-grenzen/openproject.git \
  -p GIT_BRANCH=stable/11-noupload \
  -p GIT_ACCESS_TOKEN_SECRET=$GIT_ACCESS_TOKEN_SECRET \
  -p RUBY_IMAGE_TAG=2.7.1-buster | \
  oc apply -f -
oc process \
  -f https://raw.githubusercontent.com/jngrb/openproject-openshift/master/openproject.yaml \
  -p OPENPROJECT_HOST=$OPENPROJECT_HOST \
  -p DATABASE_SECRET=openproject-database-secret \
  -p COMMUNITY_IMAGE_KIND=ImageStreamTag \
  -p COMMUNITY_IMAGE_NAME=community-fork \
  -p COMMUNITY_IMAGE_TAG=11-noupload | \
  oc apply -f -
```

For a new minor release, only merge the forked git branch with upstream and push into the forked repo.

Finally for every new release, rerun the build jobs:

```[bash]
oc start-build community-fork # needs ca. 30 minutes to build on our cluster
oc start-build community-app # only after the community-fork build completed successfully, needs only a few minutes
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
