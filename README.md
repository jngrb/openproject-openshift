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
oc -n $PROJECT process postgresql-persistent -p POSTGRESQL_USER=openproject -p POSTGRESQL_PASSWORD=openproject -p POSTGRESQL_DATABASE=openproject | oc -n $PROJECT create -f -
```

### 2 Deploy OpenProject

```
oc process -f https://raw.githubusercontent.com/jngrb/openproject-openshift/master/openproject.yaml -p OPENPROJECT_HOST=openproject.example.com | oc -n $PROJECT create -f -
```
