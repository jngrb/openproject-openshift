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

### 1 Deploy Database

```[bash]
oc -n openshift process postgresql-persistent -p POSTGRESQL_USER=openproject -p POSTGRESQL_PASSWORD=openproject -p POSTGRESQL_DATABASE=openproject | oc -n $PROJECT create -f -
```

### 2 Deploy OpenProject Initializer

For initialization, the OpenProject container must run as root. Hence, enable this feature for the projects default service account:

```[bash]
oc create sa root-allowed
oc policy add-role-to-user system:deployer -z root-allowed
oc adm policy add-scc-to-user anyuid -z root-allowed
```

Now, we can run the all-in-one community image for initialization (Change `<POSTGRESQL-PASSWORD>` to the password in the secrets of the postgresql deploment.).

```[bash]
oc process -f https://raw.githubusercontent.com/jngrb/openproject-openshift/master/openproject-initial.yaml -p OPENPROJECT_HOST=openproject-initial.example.com -p DATABASE_URL=postgres://openproject:<POSTGRESQL-PASSWORD>@postgresql.openproject.svc:5432/openproject | oc -n $PROJECT create -f -
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

### 3 Deploy Final OpenProject Application

When the initialization of the files and database is done, we can run the 'real' OpenShift deployment for OpenProject.

```[bash]
oc process -f https://raw.githubusercontent.com/jngrb/openproject-openshift/master/openproject.yaml -p OPENPROJECT_HOST=openproject.example.com -p DATABASE_URL=postgres://openproject:<POSTGRESQL-PASSWORD>@postgresq | oc -n $PROJECT create -f -
```

Finally, you can remove the initializer deployment. It is no longer needed.

```[bash]
oc delete dc community-initial
oc delete sa root-allowed
```

### 4 Settings for HTTPS

* Change the router to edge terminated HTTPS.
* Login as OpenProject administrator and change the hostname to the OpenShift routers address (`$OPENPROJECT_HOST`) and switch the 'Protocol' setting to 'HTTPS'.
