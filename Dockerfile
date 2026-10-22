# Imagen base con Java 17 (JRE)
FROM eclipse-temurin:17-jre-jammy

# Directorio de trabajo dentro del contenedor
WORKDIR /app

# Copiar el JAR generado por Maven
COPY target/hola-docker-0.0.1-SNAPSHOT.jar app.jar

# Documentar el puerto de la aplicación
EXPOSE 8080

# Comando de ejecución de Spring Boot
ENTRYPOINT ["java", "-jar", "/app/app.jar"]