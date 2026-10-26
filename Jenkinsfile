pipeline {
    agent any

    parameters {
        booleanParam(name: 'RUN_TERRAFORM', defaultValue: true,
                     description: 'Creer / mettre a jour le cluster EKS avec Terraform')
        booleanParam(name: 'DESTROY_INFRA', defaultValue: false,
                     description: 'Detruire le cluster EKS (terraform destroy) - decochez RUN_TERRAFORM')
    }

    environment {
        registry           = "roudaynakouka/docker-spring-boot"
        registryCredential = 'dockerHub'
        dockerImage        = ''
        JDK8               = '/opt/jdk8'
        AWS_DEFAULT_REGION = 'us-east-1'
        CLUSTER_NAME       = 'mykubernetes'
    }

    stages {
        stage('CHECKOUT GIT') {
            steps {
                git branch: 'main', url: 'https://github.com/roudayn-kouka/docker-spring-boot.git'
            }
        }

        stage('MVN CLEAN') {
            when { expression { !params.DESTROY_INFRA } }
            steps {
                withEnv(["JAVA_HOME=${JDK8}", "PATH+JDK=${JDK8}/bin"]) {
                    sh 'mvn -B clean'
                }
            }
        }

        stage('ARTIFACT CONSTRUCTION') {
            when { expression { !params.DESTROY_INFRA } }
            steps {
                echo 'ARTIFACT CONSTRUCTION...'
                withEnv(["JAVA_HOME=${JDK8}", "PATH+JDK=${JDK8}/bin"]) {
                    sh 'mvn -B package -DskipTests'
                }
            }
        }

        stage('UNIT TESTS') {
            when { expression { !params.DESTROY_INFRA } }
            steps {
                echo 'launching Unit Tests...'
                withEnv(["JAVA_HOME=${JDK8}", "PATH+JDK=${JDK8}/bin"]) {
                    sh 'mvn -B test'
                }
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: 'target/surefire-reports/*.xml'
                }
            }
        }

        stage('MVN SONARQUBE') {
            when { expression { !params.DESTROY_INFRA } }
            steps {
                withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
                    withEnv(["JAVA_HOME=/opt/java/openjdk", "PATH+JDK=/opt/java/openjdk/bin"]) {
                        sh '''mvn -B org.sonarsource.scanner.maven:sonar-maven-plugin:sonar \
                              -Dsonar.projectKey=docker-spring-boot \
                              -Dsonar.host.url=http://sonarqube:9000 \
                              -Dsonar.token=$SONAR_TOKEN'''
                    }
                }
            }
        }

        stage('PUBLISH TO NEXUS') {
            when { expression { !params.DESTROY_INFRA } }
            steps {
                sh 'java -version'
            }
        }

        stage('BUILDING OUR IMAGE') {
            when { expression { !params.DESTROY_INFRA } }
            steps {
                script {
                    dockerImage = docker.build registry + ":$BUILD_NUMBER"
                }
            }
        }

        stage('DEPLOY OUR IMAGE') {
            when { expression { !params.DESTROY_INFRA } }
            steps {
                script {
                    docker.withRegistry('', registryCredential) {
                        dockerImage.push()
                        dockerImage.push('latest')
                    }
                }
            }
        }

        stage('TERRAFORM APPLY (EKS)') {
            when { expression { params.RUN_TERRAFORM && !params.DESTROY_INFRA } }
            environment {
                AWS_ACCESS_KEY_ID     = credentials('aws-access-key-id')
                AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
                AWS_SESSION_TOKEN     = credentials('aws-session-token')
            }
            steps {
                dir('terraform') {
                    sh 'terraform init -input=false'
                    sh 'terraform validate'
                    sh 'terraform apply -auto-approve -input=false'
                }
            }
        }

        stage('DEPLOY TO EKS') {
            when { expression { !params.DESTROY_INFRA } }
            environment {
                AWS_ACCESS_KEY_ID     = credentials('aws-access-key-id')
                AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
                AWS_SESSION_TOKEN     = credentials('aws-session-token')
            }
            steps {
                sh 'aws sts get-caller-identity'
                sh 'aws eks update-kubeconfig --region $AWS_DEFAULT_REGION --name $CLUSTER_NAME'
                sh "sed 's#image: .*#image: ${registry}:${BUILD_NUMBER}#' deployment.yaml | kubectl apply -f -"
                sh 'kubectl apply -f service.yaml'
                sh 'kubectl rollout status deployment/my-spring-boot-app --timeout=300s'
                sh 'kubectl get nodes -o wide'
                sh 'kubectl get pods,svc'
            }
        }

        stage('TERRAFORM DESTROY (EKS)') {
            when { expression { params.DESTROY_INFRA } }
            environment {
                AWS_ACCESS_KEY_ID     = credentials('aws-access-key-id')
                AWS_SECRET_ACCESS_KEY = credentials('aws-secret-access-key')
                AWS_SESSION_TOKEN     = credentials('aws-session-token')
            }
            steps {
                dir('terraform') {
                    sh 'terraform init -input=false'
                    sh 'terraform destroy -auto-approve -input=false'
                }
            }
        }
    }
}
