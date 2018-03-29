
pipeline {

 agent {
 	label 'master'
 }

 stages {
	 
 	stage('test: validate-template') {
            steps { 
		 echo 'test:  validate-template' 
		 
		  script {
		  def branchName = sh(returnStdout: true, script: 'git rev-parse --abbrev-ref HEAD').trim()
		echo branchName
		echo env.BRANCH_NAME
		  def awsDeploymentAccount = ''
		 def deploymentRole = ''
		   if (BRANCH_NAME == "master"){ 
				awsDeploymentAccount = 'prod'//prod
				deploymentRole = 'WowAutomatedDeployment'
		 
			}
			if(Branch.isDevelopBranch(this)) {
				deploymentRole = 'WowOTRDeploymentRole'
				awsDeploymentAccount = 'dev'//dev
			}
			
			echo deploymentRole
			echo awsDeploymentAccount
		     } 
            }
         }
    }	
 post {
 	always {
 		deleteDir()
 	}
 }

}
