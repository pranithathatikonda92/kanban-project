
pipeline {

    agent any

    options {
        timestamps()
    }

    environment {
        AWS_REGION = 'ap-southeast-2'
        ECR_REGISTRY = '294615681006.dkr.ecr.ap-southeast-2.amazonaws.com'
        ECR_URI = '294615681006.dkr.ecr.ap-southeast-2.amazonaws.com/kanban-app-repo'

        DEPLOY_HOST = '172.31.43.236'
        DEPLOYMENT_STARTED = 'false'
    }

    stages {

        stage('Get Source Revision') {
            steps {
                script {
                    env.GIT_SHA = sh(
                        script: 'git rev-parse --short=8 HEAD',
                        returnStdout: true
                    ).trim()

                    env.IMAGE_TAG = "${BUILD_NUMBER}-${env.GIT_SHA}"

                    echo "Image tag: ${env.IMAGE_TAG}"
                }
            }
        }

        stage('Validate Application') {
            steps {
                sh '''
                    echo "Checking application files..."
                    test -f Dockerfile
                    test -f package.json
                    echo "Application files verified."
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                    docker build \
                    -t ${ECR_URI}:${IMAGE_TAG} \
                    -t ${ECR_URI}:latest .
                '''
            }
        }

        stage('AWS Authentication') {
            steps {
                sh '''
                    aws sts get-caller-identity

                    aws ecr get-login-password \
                    --region ${AWS_REGION} |
                    docker login \
                    --username AWS \
                    --password-stdin ${ECR_REGISTRY}
                '''
            }
        }

        stage('Push Image to ECR') {
            steps {
                sh '''
                    docker push ${ECR_URI}:${IMAGE_TAG}
                    docker push ${ECR_URI}:latest
                '''
            }
        }

        stage('Deploy to EC2') {
            steps {
                script {
                    env.DEPLOYMENT_STARTED = 'true'

                    catchError(
                        buildResult: 'FAILURE',
                        stageResult: 'FAILURE'
                    ) {
                        withCredentials([
                            sshUserPrivateKey(
                                credentialsId: 'deployment-ec2-ssh',
                                keyFileVariable: 'SSH_KEY',
                                usernameVariable: 'SSH_USER'
                            )
                        ]) {
                            sh '''
                                ssh -i "$SSH_KEY" \
                                -o BatchMode=yes \
                                -o StrictHostKeyChecking=yes \
                                "$SSH_USER@${DEPLOY_HOST}" \
                                "bash ~/deploy-kanban.sh '${IMAGE_TAG}' '${BUILD_NUMBER}'"
                            '''
                        }
                    }
                }
            }
        }

        stage('Verify Deployment') {
            when {
                expression {
                    currentBuild.currentResult == 'SUCCESS' &&
                    env.DEPLOYMENT_STARTED == 'true'
                }
            }

            steps {
                script {
                    catchError(
                        buildResult: 'FAILURE',
                        stageResult: 'FAILURE'
                    ) {
                        withCredentials([
                            sshUserPrivateKey(
                                credentialsId: 'deployment-ec2-ssh',
                                keyFileVariable: 'SSH_KEY',
                                usernameVariable: 'SSH_USER'
                            )
                        ]) {
                            sh '''
                                echo "Verifying application through Nginx..."

                                ssh -i "$SSH_KEY" \
                                -o BatchMode=yes \
                                -o StrictHostKeyChecking=yes \
                                "$SSH_USER@${DEPLOY_HOST}" \
                                "curl -fsS http://127.0.0.1/ >/dev/null && echo 'Application verification successful.'"
                            '''
                        }
                    }
                }
            }
        }

        
stage('Rollback') {
    when {
        expression {
            env.DEPLOYMENT_STARTED == 'true' &&
            currentBuild.currentResult == 'FAILURE'
        }
    }

    steps {
        withCredentials([
            sshUserPrivateKey(
                credentialsId: 'deployment-ec2-ssh',
                keyFileVariable: 'SSH_KEY',
                usernameVariable: 'SSH_USER'
            )
        ]) {
            sh '''
                echo "Deployment failed. Starting rollback..."

                if ssh -i "$SSH_KEY" \
                    -o BatchMode=yes \
                    -o StrictHostKeyChecking=yes \
                    "$SSH_USER@${DEPLOY_HOST}" \
                    "test -f /tmp/kanban-nginx-backup-${BUILD_NUMBER}"; then

                    ssh -i "$SSH_KEY" \
                        -o BatchMode=yes \
                        -o StrictHostKeyChecking=yes \
                        "$SSH_USER@${DEPLOY_HOST}" \
                        "sudo cp /tmp/kanban-nginx-backup-${BUILD_NUMBER} /etc/nginx/sites-available/kanban && sudo nginx -t && sudo systemctl reload nginx"

                    echo "Rollback completed."
                else
                    echo "No backup found. Previous application configuration remains unchanged."
                fi
            '''
        }
    }



            steps {
                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: 'deployment-ec2-ssh',
                        keyFileVariable: 'SSH_KEY',
                        usernameVariable: 'SSH_USER'
                    )
                ]) {
                    sh '''
                        echo "Deployment failed. Starting rollback..."

                        ssh -i "$SSH_KEY" \
                        -o BatchMode=yes \
                        -o StrictHostKeyChecking=yes \
                        "$SSH_USER@${DEPLOY_HOST}" \
                        "BACKUP=/tmp/kanban-nginx-backup-${BUILD_NUMBER}; CONFIG=/etc/nginx/sites-available/kanban; if [ -f \\$BACKUP ]; then sudo cp \\$BACKUP \\$CONFIG && sudo nginx -t && sudo systemctl reload nginx && echo 'Rollback successful.'; else echo 'No backup found. Previous application configuration remains unchanged.'; fi"
                    '''
                }
            }
        }
    }

    post {
        success {
            echo 'SUCCESS: CI/CD pipeline completed. Application deployed and verified!'
        }

        failure {
            echo 'FAILED: CI/CD pipeline failed. Check the stage logs and rollback result.'
        }
    }
}
