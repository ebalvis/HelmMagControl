#-------------------------------------------------------------------------------
# Name:        module1
# Purpose:     libreria a servidor control modbus
#
# Author:      ebalvis
#
# Created:     25/09/2025
# Copyright:   (c) ebalvis 2025
# Licence:     <your licence>
#-------------------------------------------------------------------------------
import socket

class WanptekClient:
    def __init__(self, host="127.0.0.1", port=4444, timeout=5):
        self.host = host
        self.port = port
        self.timeout = timeout
        self.sock = None

    def connect(self):
        """Conecta al servidor TCP"""
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.settimeout(self.timeout)
        self.sock.connect((self.host, self.port))

    def send_command(self, command):
        """Envía un comando de texto y recibe la respuesta"""
        if not self.sock:
            raise ConnectionError("No conectado al servidor")
        self.sock.sendall((command + "\n").encode("utf-8"))
        resp = self.sock.recv(1024).decode("utf-8").strip()
        return resp

    # ---- Comandos de alto nivel ----
    def set_voltage(self, channel, volts):
        return self.send_command(f"SET V{channel} {volts}")

    def set_current(self, channel, amps):
        return self.send_command(f"SET I{channel} {amps}")

    def set_output(self, channel, state: bool):
        return self.send_command(f"OUT {channel} {'ON' if state else 'OFF'}")

    def get_voltage(self, channel):
        return self.send_command(f"GET V{channel}")

    def get_current(self, channel):
        return self.send_command(f"GET I{channel}")

    def get_power(self, channel):
        return self.send_command(f"GET P{channel}")

    def get_status(self, channel):
        return self.send_command(f"STATUS {channel}")

    def all_off(self):
        return self.send_command("ALL OFF")

    def read_all(self):
        return self.send_command("READ ALL")

    def ping(self):
        return self.send_command("PING")

    def close(self):
        if self.sock:
            self.sock.close()
            self.sock = None
