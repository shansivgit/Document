
pipeline {

 agent {
 	label 'master'
 }

 stages {
	 
 	stage('test: validate-template') {
            steps { 
		 echo 'test:  validate-template' 
		 
		  script {
		echo branchName = GIT_BRANCH.split('/')[1]
		  def awsDeploymentAccount = ''
		 def deploymentRole = ''
		   if (branchName == "master"){ 
				awsDeploymentAccount = 'prod'//prod
				deploymentRole = 'WowAutomatedDeployment'
		 
			}
			if(branchName == "develop") {
				deploymentRole = 'WowOTRDeploymentRole'
				awsDeploymentAccount = 'dev'//dev
			}
			
			echo deploymentRole
			echo awsDeploymentAccount
		     } 
            }
         }
    }
}
