import os
from firefly.production.bundle import Bundle
from firefly.production.ui import TestStation
from firefly.production.scripts import ProgramScript
from firefly.production.scripts import NRF53

Bundle.set_default_bundle(os.path.join(os.path.dirname(os.path.abspath(__file__)), "resources"))


def create_test_station_script():
    fixture = test_station.fixture
    serial_wire_instrument = fixture.serial_wire_instrument
    mcu = 'nrf53_app'
    access_port_id = NRF53.access_port_id_application_ahb_ap
    firmware = 'nrf53_app_test'
    # file_system = fixture.file_system
    file_system = None
    return ProgramScript(test_station, fixture, serial_wire_instrument, mcu, firmware, file_system, access_port_id)


if __name__ == '__main__':
    test_station = TestStation(create_test_station_script)
    test_station.open()
