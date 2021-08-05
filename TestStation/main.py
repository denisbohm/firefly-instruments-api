import os
from firefly.production.bundle import Bundle
from firefly.production.ui import TestStation
from firefly.production.scripts import ProgramScript
from firefly.production.scripts import NRF53

Bundle.set_default_bundle(os.path.join(os.path.dirname(os.path.abspath(__file__)), "resources"))


def create_test_station_script():
    fixture = test_station.fixture
    mcu = 'nrf53_app'
    name = 'nrf53_app_test'
    serial_wire_instrument_number = 1
    access_port_id = NRF53.access_port_id_application_ahb_ap
    return ProgramScript(test_station, fixture, mcu, name, serial_wire_instrument_number, access_port_id)


if __name__ == '__main__':
    test_station = TestStation(create_test_station_script)
    test_station.open()
