pipeline {
    agent any

    parameters {
        booleanParam(name: 'RUN_TERRAFORM', defaultValue: true,
                     description: 'Creer / mettre a jour le cluster EKS (decochez si le cluster existe deja)')
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
        terraformDir       = 'terraform'
        // Secret file au format ~/.aws/credentials (utilise par aws, terraform et kubectl)
        AWS_SHARED_CREDENTIALS_FILE = credentials('awsCredentials')
    }

    stages {
        stage('CHECKOUT GIT') {
            steps {
                git branch: 'main', url: 'https://github.com/roudayn-kouka/docker-spring-boot.git'
            }
        }

        stage('Test AWS Credentials') {
            steps {
                sh 'aws sts get-caller-identity'
                echo 'AWS Credentials File Loaded'
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

        stage('SETUP TERRAFORM') {
            when { expression { params.RUN_TERRAFORM && !params.DESTROY_INFRA } }
            steps {
                dir(terraformDir) {
                    sh 'terraform init -input=false'
                    sh 'terraform validate'
                    sh 'terraform apply -auto-approve -input=false'
                }
            }
        }

        stage('UPDATE KUBECONFIG') {
            when { expression { !params.DESTROY_INFRA } }
            steps {
                sh 'aws eks update-kubeconfig --region $AWS_DEFAULT_REGION --name $CLUSTER_NAME'
            }
        }

        stage('DEPLOY TO AWS KUBERNETES') {
            when { expression { !params.DESTROY_INFRA } }
            steps {
                sh 'aws sts get-caller-identity'
                sh "sed 's#image: .*#image: ${registry}:${BUILD_NUMBER}#' deployment.yaml | kubectl apply -f -"
                sh 'kubectl apply -f service.yaml'
                sh 'kubectl rollout status deployment/my-spring-boot-app --timeout=300s'
                sh 'kubectl get nodes -o wide'
                sh 'kubectl get pods,svc'
            }
        }

        stage('TEARDOWN TERRAFORM') {
            when { expression { params.DESTROY_INFRA } }
            steps {
                dir(terraformDir) {
                    sh 'terraform init -input=false'
                    sh 'terraform destroy -auto-approve -input=false'
                }
            }
        }
    }
}
