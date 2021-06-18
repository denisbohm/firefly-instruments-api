import os
from firefly.production.bundle import Bundle
from firefly.production.ui import TestStation
from firefly.production.scripts import ProgramScript
from firefly.production.scripts import NRF5340

Bundle.set_default_bundle(os.path.join(os.path.dirname(os.path.abspath(__file__)), "resources"))


'''
def create_test_station_script():
    return BlinkyScript(test_station, test_station.fixture)
'''


def create_test_station_script():
    fixture = test_station.fixture
    serial_wire_instrument = fixture.serial_wire_instrument
    mcu = 'STM32F4'
    access_port_id = NRF5340.access_port_id_application_ahb_ap
    file_system = fixture.file_system
    firmware = 'firmware'
    return ProgramScript(test_station, fixture, serial_wire_instrument, mcu, access_port_id, file_system, firmware)


if __name__ == '__main__':
    test_station = TestStation(create_test_station_script)
    test_station.open()
