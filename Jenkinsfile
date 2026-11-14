
pipeline {
    agent any

    options {
        timestamps()
        skipDefaultCheckout(true)
    }

    environment {
        AWS_REGION = 'ap-southeast-2'
        ECR_REGISTRY = '294615681006.dkr.ecr.ap-southeast-2.amazonaws.com'
        ECR_URI = '294615681006.dkr.ecr.ap-southeast-2.amazonaws.com/kanban-app-repo'

        DEPLOY_HOST = '172.31.43.236'
    }

    stages {

        stage('Checkout Source') {
            steps {
                checkout scm

                script {
                    env.GIT_SHA = sh(
                        script: 'git rev-parse --short=8 HEAD',
                        returnStdout: true
                    ).trim()

                    env.IMAGE_TAG = "${BUILD_NUMBER}-${env.GIT_SHA}"

                    echo "Git commit: ${env.GIT_SHA}"
                    echo "Docker image tag: ${env.IMAGE_TAG}"
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
                    echo "Building Docker image..."

                    docker build \
                        -t ${ECR_URI}:${IMAGE_TAG} \
                        -t ${ECR_URI}:latest .

                    echo "Docker image built successfully."
                '''
            }
        }
        stage('Trivy Security Scan') {
            steps {
                sh '''
                    echo "Scanning Docker image for HIGH and CRITICAL vulnerabilities..."

                    trivy image \
                        --severity HIGH,CRITICAL \
                        --exit-code 1 \
                        ${ECR_URI}:${IMAGE_TAG}

                    echo "Trivy security scan passed."
                '''
            }
        }
        stage('AWS Authentication') {
            steps {
                sh '''
                    echo "Checking AWS identity..."
                    aws sts get-caller-identity

                    echo "Logging in to Amazon ECR..."

                    aws ecr get-login-password \
                        --region ${AWS_REGION} |
                    docker login \
                        --username AWS \
                        --password-stdin ${ECR_REGISTRY}

                    echo "ECR authentication successful."
                '''
            }
        }

        stage('Push Image to ECR') {
            steps {
                sh '''
                    echo "Pushing versioned image..."
                    docker push ${ECR_URI}:${IMAGE_TAG}

                    echo "Pushing latest image..."
                    docker push ${ECR_URI}:latest

                    echo "Images pushed successfully."
                '''
            }
        }

        stage('Deploy to EC2') {
            steps {
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
                            echo "Starting deployment on EC2..."

                            ssh -i "$SSH_KEY" \
                                -o BatchMode=yes \
                                -o StrictHostKeyChecking=yes \
                                "$SSH_USER@${DEPLOY_HOST}" \
                                "bash ~/deploy-kanban.sh '${IMAGE_TAG}' '${BUILD_NUMBER}'"

                            echo "Deployment script completed."
                        '''
                    }
                }
            }
        }

        stage('Verify Deployment') {
            when {
                expression {
                    currentBuild.currentResult == 'SUCCESS'
                }
            }

            steps {
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
                                "curl -fsS http://127.0.0.1/ | grep -qi '<html'"

                            echo "Application verification successful."
                        '''
                    }
                }
            }
        }

        stage('Rollback') {
            steps {
                script {
                    if (currentBuild.currentResult == 'FAILURE') {

                        echo "Pipeline failed. Starting rollback..."

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
                                    "if [ -f /tmp/kanban-nginx-backup-${BUILD_NUMBER} ]; then sudo cp /tmp/kanban-nginx-backup-${BUILD_NUMBER} /etc/nginx/sites-available/kanban && sudo nginx -t && sudo systemctl reload nginx && echo 'Rollback successful.'; else echo 'No backup found. Previous application configuration remains unchanged.'; fi"
                            '''
                        }

                    } else {
                        echo "No rollback required. Deployment and verification succeeded."
                    }
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

        always {
            echo "Pipeline execution finished. Build number: ${BUILD_NUMBER}"
        }
    }
}
