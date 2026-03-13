FROM eclipse-temurin:11-jre-alpine
RUN mkdir /opt/app && mkdir /files
COPY target/shopizer.jar /opt/app
COPY SALESMANAGER.h2.db /
CMD ["java", "-jar", "/opt/app/shopizer.jar"]
