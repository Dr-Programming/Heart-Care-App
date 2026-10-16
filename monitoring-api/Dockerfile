# Two stages: compile with Maven, then run on a JRE-only image (same pattern as backend/).

FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /build

COPY pom.xml .
RUN mvn -B -q dependency:go-offline

COPY src ./src
RUN mvn -B -q package -DskipTests


FROM eclipse-temurin:21-jre
WORKDIR /app

RUN groupadd --system app && useradd --system --gid app app
COPY --from=build /build/target/*.jar app.jar
USER app

EXPOSE 8090
HEALTHCHECK --interval=30s --timeout=3s --start-period=40s \
    CMD ["bash", "-c","exec 3<>/dev/tcp/127.0.0.1/8090 && printf 'GET /actuator/health HTTP/1.0\\r\\n\\r\\n' >&3 && grep -q UP <&3"]
ENTRYPOINT ["java", "-jar", "app.jar"]
