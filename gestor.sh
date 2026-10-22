#!/usr/bin/env bash

# ======================================================
# UNIR - Computación Cliente-servidor
# Actividad: Scripting Bash y despliegue con Docker
# Archivo: gestor.sh
# ======================================================

# Variables de configuración
PROJECT_NAME="hola-docker"
IMAGE_NAME="hola-docker:1.0"
CONTAINER_NAME="hola-docker-container"
JAR_PATH="target/hola-docker-0.0.1-SNAPSHOT.jar"

# Colores ANSI para la interfaz
VERDE='\033[0;32m'
AZUL='\033[0;34m'
AMARILLO='\033[0;33m'
ROJO='\033[0;31m'
CYAN='\033[0;36m'
NEGRITA='\033[1m'
RESET='\033[0m'

# Función para mostrar el menú principal
mostrar_menu() {
    echo ""
    printf '%b==========================================%b\n' "$CYAN" "$RESET"
    printf '%b%b      GESTOR DE APLICACIÓN - UNIR%b\n' "$VERDE" "$NEGRITA" "$RESET"
    printf '%b==========================================%b\n' "$CYAN" "$RESET"
    printf '%b Proyecto: %s%b\n' "$AMARILLO" "$PROJECT_NAME" "$RESET"
    printf '%b------------------------------------------%b\n' "$CYAN" "$RESET"
    printf ' %b1.%b Verificar prerrequisitos\n' "$AZUL" "$RESET"
    printf ' %b2.%b Compilar y empaquetar aplicación\n' "$AZUL" "$RESET"
    printf ' %b3.%b Construir imagen Docker\n' "$AZUL" "$RESET"
    printf ' %b4.%b Ejecutar contenedor Docker\n' "$AZUL" "$RESET"
    printf ' %b5.%b Mostrar estado actual\n' "$AZUL" "$RESET"
    printf ' %b6.%b Salir\n' "$AZUL" "$RESET"
    printf '%b==========================================%b\n' "$CYAN" "$RESET"
}


# ======================================================
# OPCIÓN 1: VERIFICACIÓN DE PRERREQUISITOS
# ======================================================

verificar_prerrequisitos() {

    printf '\n%b=== VERIFICACIÓN DE PRERREQUISITOS ===%b\n' "$CYAN" "$RESET"

    # Verificar disponibilidad de comandos mediante un bucle for
    for comando in java docker; do

        if command -v "$comando" >/dev/null 2>&1; then
            printf '%b[OK]%b %s está instalado.\n' "$VERDE" "$RESET" "$comando"

        else
            printf '%b[ERROR]%b %s no está instalado.\n' "$ROJO" "$RESET" "$comando"
        fi

    done

    # Verificar Maven Wrapper o Maven global
    if [[ -f "./mvnw" ]]; then
        printf '%b[OK]%b Maven Wrapper disponible.\n' "$VERDE" "$RESET"

    elif command -v mvn >/dev/null 2>&1; then
        printf '%b[OK]%b Maven instalado globalmente.\n' "$VERDE" "$RESET"

    else
        printf '%b[ERROR]%b Maven no está disponible.\n' "$ROJO" "$RESET"
    fi

    # Verificar que Java sea versión 17 o superior
    if command -v java >/dev/null 2>&1; then

        printf '\n%bVersión de Java:%b\n' "$AZUL" "$RESET"
        java --version

        JAVA_VERSION=$(java -version 2>&1 |
            awk -F '"' '/version/ {print $2}' |
            cut -d. -f1)

        if [[ "$JAVA_VERSION" =~ ^[0-9]+$ ]] && (( JAVA_VERSION >= 17 )); then
            printf '%b[OK]%b Java cumple la versión mínima requerida.\n' "$VERDE" "$RESET"
        else
            printf '%b[ERROR]%b Se requiere Java 17 o superior.\n' "$ROJO" "$RESET"
        fi

    fi

    # Verificar si Docker Engine responde
    if command -v docker >/dev/null 2>&1; then

        if docker info >/dev/null 2>&1; then
            printf '\n%b[OK] Docker Engine está funcionando.%b\n' "$VERDE" "$RESET"

        else
            printf '\n%b[AVISO] Docker está instalado, pero el motor no responde.%b\n' "$AMARILLO" "$RESET"
        fi

    fi

    printf '%b======================================%b\n' "$CYAN" "$RESET"
}


# ======================================================
# OPCIÓN 2: COMPILAR Y EMPAQUETAR LA APLICACIÓN
# ======================================================

compilar_aplicacion() {

    printf '\n%b=== COMPILACIÓN Y EMPAQUETADO ===%b\n' "$CYAN" "$RESET"
    printf '%bProyecto:%b %s\n' "$AZUL" "$RESET" "$PROJECT_NAME"

    # Comprobar que Maven Wrapper está disponible
    if [[ -f "./mvnw" ]]; then
        printf '%b[OK]%b Maven Wrapper encontrado.\n' "$VERDE" "$RESET"

    elif command -v mvn >/dev/null 2>&1; then
        printf '%b[AVISO]%b Se utilizará Maven global.\n' "$AMARILLO" "$RESET"

    else
        printf '%b[ERROR]%b Maven no está disponible.\n' "$ROJO" "$RESET"
        return 1
    fi

    # Ejecutar compilación y empaquetado
    printf '\n%b[INFO] Iniciando compilación...%b\n' "$AZUL" "$RESET"

    if [[ -f "./mvnw" ]]; then
        if ! bash ./mvnw clean package -DskipTests; then
            printf '%b[ERROR] Falló la compilación Maven.%b\n' "$ROJO" "$RESET"
            return 1
        fi
    else
        if ! mvn clean package -DskipTests; then
            printf '%b[ERROR] Falló la compilación Maven.%b\n' "$ROJO" "$RESET"
            return 1
        fi
    fi

    # Validar que el JAR fue generado
    if [[ -f "$JAR_PATH" ]]; then
        printf '\n%b[OK] Compilación exitosa.%b\n' "$VERDE" "$RESET"
        printf '%b[OK] Archivo JAR generado:%b %s\n' "$VERDE" "$RESET" "$JAR_PATH"

        # Mostrar el tamaño del archivo
        ls -lh "$JAR_PATH"
    else
        printf '\n%b[ERROR] No se encontró el JAR esperado.%b\n' "$ROJO" "$RESET"
        printf '%b[AVISO] Verifica la versión del proyecto en pom.xml.%b\n' "$AMARILLO" "$RESET"
        return 1
    fi

    printf '%b======================================%b\n' "$CYAN" "$RESET"
}


# ======================================================
# OPCIÓN 3: CONSTRUIR IMAGEN DOCKER
# ======================================================

construir_imagen() {

    printf '\n%b=== CONSTRUCCIÓN DE IMAGEN DOCKER ===%b\n' "$CYAN" "$RESET"

    # 1. Comprobar que existe el archivo JAR
    if [[ ! -f "$JAR_PATH" ]]; then
        printf '%b[ERROR]%b No se encontró el archivo JAR.\n' "$ROJO" "$RESET"
        printf '%b[AVISO]%b Primero debes compilar la aplicación (opción 2).\n' "$AMARILLO" "$RESET"
        return 1
    fi

    printf '%b[OK]%b Archivo JAR encontrado: %s\n' "$VERDE" "$RESET" "$JAR_PATH"

    # 2. Verificar que Docker está instalado
    if ! command -v docker >/dev/null 2>&1; then
        printf '%b[ERROR]%b Docker no está instalado.\n' "$ROJO" "$RESET"
        return 1
    fi

    # 3. Verificar que Docker Engine está funcionando
    if ! docker info >/dev/null 2>&1; then
        printf '%b[ERROR]%b Docker Engine no está disponible.\n' "$ROJO" "$RESET"
        printf '%b[AVISO]%b Inicia Docker Desktop e inténtalo nuevamente.\n' "$AMARILLO" "$RESET"
        return 1
    fi

    # 4. Verificar que existe el Dockerfile
    if [[ ! -f "Dockerfile" ]]; then
        printf '%b[ERROR]%b No se encontró el Dockerfile.\n' "$ROJO" "$RESET"
        return 1
    fi

    # 5. Construir la imagen Docker
    printf '\n%b[INFO]%b Construyendo imagen: %s\n' "$AZUL" "$RESET" "$IMAGE_NAME"

    if docker build -t "$IMAGE_NAME" .; then
        printf '\n%b[OK]%b Imagen Docker construida correctamente.\n' "$VERDE" "$RESET"
    else
        printf '\n%b[ERROR]%b Falló la construcción de la imagen Docker.\n' "$ROJO" "$RESET"
        return 1
    fi

    # 6. Confirmar que la imagen existe
    if docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
        printf '%b[OK]%b Imagen verificada: %s\n' "$VERDE" "$RESET" "$IMAGE_NAME"

        printf '\n%bInformación de la imagen:%b\n' "$AZUL" "$RESET"
        docker image ls "$IMAGE_NAME"
    else
        printf '%b[ERROR]%b No se pudo verificar la imagen generada.\n' "$ROJO" "$RESET"
        return 1
    fi

    printf '%b======================================%b\n' "$CYAN" "$RESET"
}


# ======================================================
# OPCIÓN 4: EJECUTAR CONTENEDOR DOCKER
# ======================================================

ejecutar_contenedor() {

    printf '\n%b=== EJECUCIÓN DEL CONTENEDOR ===%b\n' "$CYAN" "$RESET"

    # 1. Verificar Docker Engine
    if ! docker info >/dev/null 2>&1; then
        printf '%b[ERROR]%b Docker Engine no está disponible.\n' "$ROJO" "$RESET"
        return 1
    fi

    # 2. Verificar que existe la imagen
    if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
        printf '%b[ERROR]%b La imagen %s no existe.\n' "$ROJO" "$RESET" "$IMAGE_NAME"
        printf '%b[AVISO]%b Ejecuta primero la opción 3.\n' "$AMARILLO" "$RESET"
        return 1
    fi

    printf '%b[OK]%b Imagen Docker encontrada.\n' "$VERDE" "$RESET"

    # 3. Comprobar si existe un contenedor con el mismo nombre
    if docker container inspect "$CONTAINER_NAME" >/dev/null 2>&1; then

        printf '\n%b[AVISO]%b Ya existe el contenedor: %s\n' "$AMARILLO" "$RESET" "$CONTAINER_NAME"

        printf '%bEstado actual:%b\n' "$AZUL" "$RESET"
        docker ps -a --filter "name=^/${CONTAINER_NAME}$"

        printf '\n%b¿Deseas detenerlo y eliminarlo para crear uno nuevo? [s/N]: %b' "$AMARILLO" "$RESET"
        read -r confirmacion

        if [[ "$confirmacion" == "s" || "$confirmacion" == "S" ]]; then

            printf '\n%b[INFO]%b Eliminando contenedor anterior...\n' "$AZUL" "$RESET"

            if ! docker rm -f "$CONTAINER_NAME"; then
                printf '%b[ERROR]%b No se pudo eliminar el contenedor.\n' "$ROJO" "$RESET"
                return 1
            fi

            printf '%b[OK]%b Contenedor anterior eliminado.\n' "$VERDE" "$RESET"

        else
            printf '%b[INFO]%b Operación cancelada. Se conserva el contenedor existente.\n' "$AMARILLO" "$RESET"
            return 0
        fi
    fi

    # 4. Ejecutar el nuevo contenedor
    printf '\n%b[INFO]%b Iniciando contenedor...\n' "$AZUL" "$RESET"

    if ! docker run -d \
        --name "$CONTAINER_NAME" \
        -p 8080:8080 \
        "$IMAGE_NAME"; then

        printf '%b[ERROR]%b No se pudo crear el contenedor.\n' "$ROJO" "$RESET"
        return 1
    fi

    # 5. Comprobar que el contenedor está ejecutándose
    if [[ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null)" == "true" ]]; then

        printf '\n%b[OK]%b Contenedor iniciado correctamente.\n' "$VERDE" "$RESET"

        printf '%bInformación del contenedor:%b\n' "$AZUL" "$RESET"
        docker ps --filter "name=^/${CONTAINER_NAME}$"

        printf '\n%bAplicación disponible en:%b\n' "$CYAN" "$RESET"
        printf "http://localhost:8080/hello\n"
        printf '%b[INFO]%b Comprueba el endpoint para confirmar que Spring Boot terminó de iniciar.\n' "$AMARILLO" "$RESET"

    else
        printf '%b[ERROR]%b El contenedor no permanece en ejecución.\n' "$ROJO" "$RESET"
        printf '%b[INFO]%b Consulta los logs para investigar la causa.\n' "$AMARILLO" "$RESET"
        docker logs --tail 30 "$CONTAINER_NAME"
        return 1
    fi

    printf '%b======================================%b\n' "$CYAN" "$RESET"
}


# ======================================================
# OPCIÓN 5: CONSULTAR ESTADO DE LA APLICACIÓN
# ======================================================

mostrar_estado() {

    printf '\n%b=== ESTADO ACTUAL DE LA APLICACIÓN ===%b\n' "$CYAN" "$RESET"

    # 1. Estado del archivo JAR
    printf '\n%b[1] ARCHIVO JAR%b\n' "$AZUL" "$RESET"

    if [[ -f "$JAR_PATH" ]]; then
        printf '%b[OK]%b Archivo disponible: %s\n' "$VERDE" "$RESET" "$JAR_PATH"

        # Mostrar tamaño del archivo
        du -h "$JAR_PATH"
    else
        printf '%b[AVISO]%b No existe el JAR compilado.\n' "$AMARILLO" "$RESET"
    fi

    # 2. Verificar disponibilidad de Docker
    if ! command -v docker >/dev/null 2>&1; then
        printf '\n%b[ERROR]%b Docker no está instalado.\n' "$ROJO" "$RESET"
        return 1
    fi

    if ! docker info >/dev/null 2>&1; then
        printf '\n%b[ERROR]%b Docker Engine no está disponible.\n' "$ROJO" "$RESET"
        return 1
    fi

    # 3. Estado de la imagen Docker
    printf '\n%b[2] IMAGEN DOCKER%b\n' "$AZUL" "$RESET"

    if docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then

        printf '%b[OK]%b Imagen disponible: %s\n' "$VERDE" "$RESET" "$IMAGE_NAME"

        printf '%bFecha de creación:%b\n' "$CYAN" "$RESET"
        docker image inspect \
            --format '{{.Created}}' \
            "$IMAGE_NAME"

        printf '\n%bInformación de la imagen:%b\n' "$CYAN" "$RESET"
        docker image ls "$IMAGE_NAME"

    else
        printf '%b[AVISO]%b La imagen no existe.\n' "$AMARILLO" "$RESET"
    fi

    # 4. Estado del contenedor
    printf '\n%b[3] CONTENEDOR DOCKER%b\n' "$AZUL" "$RESET"

    if docker container inspect "$CONTAINER_NAME" >/dev/null 2>&1; then

        estado=$(docker inspect \
            --format '{{.State.Status}}' \
            "$CONTAINER_NAME")

        if [[ "$estado" == "running" ]]; then
            printf '%b[OK]%b Contenedor en ejecución.\n' "$VERDE" "$RESET"

        elif [[ "$estado" == "exited" ]]; then
            printf '%b[AVISO]%b Contenedor detenido.\n' "$AMARILLO" "$RESET"

        else
            printf '%b[INFO]%b Estado: %s\n' "$AMARILLO" "$RESET" "$estado"
        fi

        printf '\n%bInformación del contenedor:%b\n' "$CYAN" "$RESET"

        docker ps -a \
            --filter "name=^/${CONTAINER_NAME}$"

    else
        printf '%b[AVISO]%b No existe el contenedor.\n' "$AMARILLO" "$RESET"
    fi

    printf '\n%b======================================%b\n' "$CYAN" "$RESET"
}


# Bucle principal del programa
while true; do

    mostrar_menu

    printf '%bSeleccione una opción [1-6]: %b' "$CYAN" "$RESET"
    read -r opcion

    if [[ "$opcion" == "1" ]]; then
        verificar_prerrequisitos

    elif [[ "$opcion" == "2" ]]; then
        compilar_aplicacion

    elif [[ "$opcion" == "3" ]]; then
        construir_imagen

    elif [[ "$opcion" == "4" ]]; then
        ejecutar_contenedor

    elif [[ "$opcion" == "5" ]]; then
        mostrar_estado

    elif [[ "$opcion" == "6" ]]; then
        echo ""
        printf '%bFinalizando el gestor de %s.%b\n' "$VERDE" "$PROJECT_NAME" "$RESET"
        printf '%b¡Hasta pronto!%b\n' "$VERDE" "$RESET"
        exit 0

    else
        echo ""
        printf '%bERROR: opción no válida. Seleccione entre 1 y 6.%b\n' "$ROJO" "$RESET"
    fi

done
