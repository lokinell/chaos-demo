FROM maven:3.8.4-openjdk-11-slim AS build
WORKDIR /app
COPY pom.xml .
# Download dependencies
RUN mvn dependency:go-offline -B
COPY src ./src
# Build the application
RUN mvn package -DskipTests

FROM openjdk:11-jre-slim
WORKDIR /app
# Copy the built JAR file
COPY --from=build /app/target/chaos-java-service-0.0.1-SNAPSHOT.jar app.jar
# JVM options for better containerization
ENV JAVA_OPTS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0"
EXPOSE 8081
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"] 