#-------------------------------------------------------------------------------
# Name:        module1
# Purpose:
#
# Author:      ebalvis
#
# Created:     25/09/2025
# Copyright:   (c) ebalvis 2025
# Licence:     <your licence>
#-------------------------------------------------------------------------------
from wanptek_control import WanptekClient

client = WanptekClient("127.0.0.1", 4444)
client.connect()

# Probar comunicación
print(client.ping())            # -> OK PONG
# Leer valores
print(client.get_voltage(1))
print(client.get_current(1))
print(client.get_power(1))
# Ajustar canal 1 a 5V
print(client.set_voltage(1, 15.9))
# Ajustar canal 1 a 5V
print(client.set_current(1, 9.3))
# Activar salida canal 1
print(client.set_output(1, True))
print(client.set_output(2, True))
print(client.set_output(3, True))


# Estado completo
print(client.read_all())

# Apagar todo
print(client.all_off())

client.close()
