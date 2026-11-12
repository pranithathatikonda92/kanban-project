
pipeline {

    agent {
        node {
            customWorkspace '/home/ubuntu/new-project/kanban-dashboard'
        }
    }

    environment {
        AWS_REGION = 'ap-southeast-2'
        AWS_ACCOUNT_ID = '294615681006'
        ECR_REPOSITORY = 'kanban-app-repo'
        IMAGE_TAG = "${BUILD_NUMBER}"
        ECR_REGISTRY = '294615681006.dkr.ecr.ap-southeast-2.amazonaws.com'
        ECR_URI = '294615681006.dkr.ecr.ap-southeast-2.amazonaws.com/kanban-app-repo'
    }

    stages {

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
    }

    post {
        success {
            echo 'SUCCESS: Docker image pushed to Amazon ECR!'
        }

        failure {
            echo 'FAILED: Please check the Jenkins console output.'
        }
    }
}

