//test
branchs_name = "master"
cur_job_name = "job-testscript"
secret_token = "YxGB-DNsy_YsUKwL6J7u"

def createDeploymentJob(jobName, repoUrl, brans, secrets) {
    pipelineJob(jobName) {
        triggers {
            gitlab{
            triggerOnPush(true)
            triggerOnMergeRequest(false)
            triggerOnAcceptedMergeRequest(true)
            triggerOnClosedMergeRequest(false)
            triggerOpenMergeRequestOnPush("never")
            triggerOnNoteRequest(true)
            noteRegex( "Jenkins please retry a build")
            //skipWorkInProgressMergeRequest( true)
            //ciSkip( false)
            //setBuildDescription( true)
            //addNoteOnMergeRequest( true)
            //addCiMessage( true)
            //addVoteOnMergeRequest( true)
            //acceptMergeRequestOnSuccess( false)
            //pendingBuildName( "Jenkins")
            //cancelPendingBuildsOnUpdate( false)
            secretToken(secrets)
    }
  }

        definition {
            cpsScm {
                scm {
                    git {
                        remote {
                            url(repoUrl)
                            credentials("218fd592-da99-40e4-9a72-04415b80203d")
                        }
                        branches("*/"+brans)
                        extensions {
                            cleanBeforeCheckout()
                        }
                    }
                }
                scriptPath("Jenkinsfile")
            }
        }
    }
}

def createTestJob(jobName, repoUrl, brans, secrets) {
/*
    multibranchPipelineJob(jobName) {
        branchSources {
            git {
                remote(repoUrl)
                credentialsId('218fd592-da99-40e4-9a72-04415b80203d')
                includes('*')
            }
        }
        triggers {
            cron("H/5 * * * *")
        }
    }
*/    
}

def buildPipelineJobs(jobName, brans, secrets) {
    def repo = "git@gitlab.haas-495.pez.vmware.com:jeffrey/"
    def repoUrl = repo + jobName + ".git"
    def deployName = jobName + "_deploy"
    def testName = jobName + "_test"

    //createDeploymentJob(deployName, repoUrl)
    //createTestJob(testName, repoUrl)
    createDeploymentJob(jobName, repoUrl, brans, secrets)
}

buildPipelineJobs(cur_job_name, branchs_name, secret_token)