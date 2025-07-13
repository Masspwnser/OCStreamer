FROM maven:3-eclipse-temurin-24-alpine AS build

COPY . /app
WORKDIR /app

RUN mvn clean package

FROM eclipse-temurin:24-jre-alpine AS runtime

RUN apk --no-cache add firefox

COPY --from=build /app/target/ocstreamer-server-1.0.0-jar-with-dependencies.jar /app/server.jar

EXPOSE 56795

ENTRYPOINT ["java", "-jar", "/app/server.jar"]