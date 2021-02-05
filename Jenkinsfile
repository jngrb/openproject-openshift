pipeline {
    agent any
    stages {
        stage('Build info') {
            steps {
              sh 'env'
            }
        }

        stage('Checkout sources') {
            steps {
                checkout changelog: false, poll: false,
                    scm: [$class: 'GitSCM', branches: [[name: "${env.GIT_BRANCH}"]],
                    doGenerateSubmoduleConfigurations: false, extensions: [], submoduleCfg: [],
                    userRemoteConfigs: [[url: "${env.GIT_URL}"]]]
            }
        }

        stage('Rebuild forked openproject image') {
            steps {
                script {
                    if (env.BUILD_FORK_IMAGE.toBoolean()) {
                        // increase timeout
                        timeout(time: 60, unit: 'MINUTES') {
                            // consider changes in nc_image_fix/Dockerfile
                            openshift.withCluster() {
                                openshift.withProject(/*"${env.PROJECT_NAME}"*/) {
                                    def buildSelector = openshift.selector("bc", 'community-fork')
                                    buildSelector.startBuild("--follow=true")
                                    /* Alternatively to "--follow=true":
                                        * Do some parallel tasks while building.
                                        * When needed to wait for the build again and show logs, do:
                                        * build.logs('-f') */
                                }
                            }
                        }
                    }
                }
            }
        }

        stage('Apply configuration update') {
            steps {
                script {
                    // consider changes in openproject.yaml
                    openshift.withCluster() {
                        openshift.withProject(/*"${env.PROJECT_NAME}"*/) {
                            def template = readFile 'openproject.yaml'
                            def config = null
                            if (env.BUILD_FORK_IMAGE.toBoolean()) {
                                config = openshift.process(template,
                                  '-p', "PVC_SIZE=${env.PVC_SIZE}",
                                  '-p', "EXTERNAL_OPENPROJECT_HOST=${env.EXTERNAL_OPENPROJECT_HOST}",
                                  '-p', "INTERNAL_OPENPROJECT_HOST=${env.INTERNAL_OPENPROJECT_HOST}",
                                  '-p', "DATABASE_SECRET=${env.DATABASE_SECRET}",
                                  '-p', "COMMUNITY_IMAGE_KIND=ImageStreamTag",
                                  '-p', "COMMUNITY_IMAGE_NAME=community-fork",
                                  '-p', "COMMUNITY_IMAGE_TAG=${env.COMMUNITY_IMAGE_TAG}")
                            } else {
                                config = openshift.process(template,
                                  '-p', "PVC_SIZE=${env.PVC_SIZE}",
                                  '-p', "EXTERNAL_OPENPROJECT_HOST=${env.EXTERNAL_OPENPROJECT_HOST}",
                                  '-p', "INTERNAL_OPENPROJECT_HOST=${env.INTERNAL_OPENPROJECT_HOST}",
                                  '-p', "DATABASE_SECRET=${env.DATABASE_SECRET}",
                                  '-p', "COMMUNITY_IMAGE_NAME=${env.COMMUNITY_IMAGE_NAME}",
                                  '-p', "COMMUNITY_IMAGE_TAG=${env.COMMUNITY_IMAGE_TAG}")
                            }
                            openshift.apply(config)
                        }
                    }
                }
            }
        }

        stage('Apply openidc update') {
            steps {
                script {
                    openshift.withCluster() {
                        openshift.withProject(/*"${env.PROJECT_NAME}"*/) {
                            def template = readFile 'apache-openidc/apache-oidc-proxy.yml'
                            def config = openshift.process(template,
                                '-p', "PUBLIC_OPENPROJECT_HOST=${env.EXTERNAL_OPENPROJECT_HOST}",
                                '-p', "OIDC_METADATA_URL=${env.OIDC_METADATA_URL}")
                            openshift.apply(config)
                        }
                    }
                }
            }
        }

        stage('Rebuild openproject-for-openshift image') {
            steps {
                script {
                    // consider changes in Dockerfile and nginx.conf
                    openshift.withCluster() {
                        openshift.withProject(/*"${env.PROJECT_NAME}"*/) {
                            // set timeout to 10 minutes
                            timeout(time: 10, unit: 'MINUTES') {
                                def buildSelector = openshift.selector("bc", 'community-app')
                                buildSelector.startBuild("--follow=true")
                                /* Alternatively to "--follow=true":
                                     * Do some parallel tasks while building.
                                     * When needed to wait for the build again and show logs, do:
                                     * build.logs('-f') */
                            }
                        }
                    }
                }
            }
        }

        stage('Rebuild OpenID-Connect image') {
            steps {
                script {
                    if (false /*env.BUILD_FORK_IMAGE.toBoolean()*/) {
                        // increase timeout
                        timeout(time: 60, unit: 'MINUTES') {
                            openshift.withCluster() {
                                openshift.withProject(/*"${env.PROJECT_NAME}"*/) {
                                    def buildSelector = openshift.selector("bc", 'apache-oidc-proxy')
                                    buildSelector.startBuild("--follow=true")
                                    /* Alternatively to "--follow=true":
                                        * Do some parallel tasks while building.
                                        * When needed to wait for the build again and show logs, do:
                                        * build.logs('-f') */
                                }
                            }
                        }
                    }
                }
            }
        }

        stage('Wait for rollout to complete') {
            steps {
                script {
                    openshift.withCluster() {
                        openshift.withProject(/*"${env.PROJECT_NAME}"*/) {
                            def templateName = 'community'
                            /*def rm = openshift.selector("dc", templateName)
                              .rollout().latest()*/
                            timeout(10) {
                                openshift.selector("dc", templateName)
                                  .related('pods').untilEach(1) {
                                    return (it.object().status.phase == "Running")
                                }
                            }

                            def templateName2 = 'apache-oidc-proxy'
                            /*def rm = openshift.selector("dc", templateName2)
                              .rollout().latest()*/
                            timeout(10) {
                                openshift.selector("dc", templateName2)
                                  .related('pods').untilEach(1) {
                                    return (it.object().status.phase == "Running")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
