#-------------------------------------------------------------------------------
# Name:        module1
# Purpose:      cliente udp para medidas sensor movil
#
# Author:      ebalvis
#
# Created:     25/09/2025
# Copyright:   (c) ebalvis 2025
# Licence:     <your licence>
#-------------------------------------------------------------------------------

import socket

# IP del servidor Android y puerto que usaste en B4A
SERVER_IP = "192.168.137.12"   # cámbiala por la IP real de tu teléfono con B4A
SERVER_PORT = 51042

# Crear socket UDP
sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

# Si quieres recibir desde el servidor, debes enlazar tu PC a un puerto
sock.bind(("0.0.0.0", 51043))  # puerto del PC para recibir mensajes del servidor

# Registrar el cliente enviando "REGISTER_ME"
sock.sendto(b"HOLA", (SERVER_IP, SERVER_PORT))
print(f"Cliente registrado en {SERVER_IP}:{SERVER_PORT}")

# Bucle para recibir datos
try:
    while True:
        data, addr = sock.recvfrom(1024)
        print(f"Mensaje desde {addr}: {data.decode('utf-8')}")
except KeyboardInterrupt:
    print("Cerrando conexión...")
finally:
    sock.close()
