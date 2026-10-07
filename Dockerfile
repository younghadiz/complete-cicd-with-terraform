FROM amazoncorretto:17-alpine-jdk

WORKDIR /app

COPY target/java-maven-app-*.jar /app/app.jar

USER 10001:10001

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "/app/app.jar"]
