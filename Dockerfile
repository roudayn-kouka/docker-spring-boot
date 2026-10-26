
FROM eclipse-temurin:8-jdk-alpine

WORKDIR /

COPY target/docker-spring-boot.war app.war

EXPOSE 8083

ENTRYPOINT ["java", "-jar", "/app.war"]
