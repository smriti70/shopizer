FROM maven:3.8-eclipse-temurin-11-alpine AS builder
WORKDIR /app
COPY . .
RUN mvn install -pl sm-core-model,sm-core -am -DskipTests -q && mvn package -pl sm-shop -DskipTests -q

FROM eclipse-temurin:11-jre-alpine
RUN mkdir /opt/app && mkdir /files
COPY --from=builder /app/sm-shop/target/shopizer.jar /opt/app/shopizer.jar
COPY sm-shop/SALESMANAGER.h2.db /
CMD ["java", "-jar", "/opt/app/shopizer.jar"]
