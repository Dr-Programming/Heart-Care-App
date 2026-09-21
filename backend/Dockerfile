# Two stages: compile with Maven, then run on a JRE-only image so the build toolchain
# and the Maven cache never ship.

FROM maven:3.9-eclipse-temurin-21 AS build
WORKDIR /build

# Dependencies change far less often than source. Resolving them in their own layer means a
# code-only change rebuilds from here down instead of re-downloading everything.
COPY pom.xml .
RUN mvn -B -q dependency:go-offline

COPY src ./src
# Tests are skipped: they start PostgreSQL through Testcontainers, which needs a Docker daemon
# that a build container does not have. Run `mvn test` on the host.
RUN mvn -B -q package -DskipTests


FROM eclipse-temurin:21-jre
WORKDIR /app

RUN groupadd --system app && useradd --system --gid app app
COPY --from=build /build/target/*.jar app.jar
USER app

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
