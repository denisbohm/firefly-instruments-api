import time
from .bundle import Bundle
from .instruments import GpioInstrument
from .instruments import InstrumentManager
from .instruments import SerialWireInstrument
from .instruments import SerialWireDebugTransfer
from .instruments import StorageInstrument
from .storage import FileSystem
from elftools.elf.elffile import ELFFile


class Fixture:

    def __init__(self, presenter):
        self.presenter = presenter
        self.manager = None
        self.indicator_instrument = None
        self.serial_wire_instruments = []
        self.storage_instrument = None
        self.file_system = None
        self.gpio_instruments = []
        self.battery_instrument = None
        self.relay_sense = None
        self.relay_battery_to_dut = None
        self.relay_supercap_to_dut = None
        self.relay_fill_supercap = None
        self.relay_drain_supercap = None
        self.relay_vusb_to_dut = None
        self.relay_dusb_to_dut = None
        self.voltage_battery_instrument = None
        self.voltage_supercap_instrument = None
        self.current_usb_instrument = None

    def setup(self):
        self.manager = InstrumentManager()
        self.manager.open()
        self.manager.discover_instruments()

        self.indicator_instrument = self.manager.get_instrument(1)
        self.indicator_instrument.set(0.0, 0.0, 1.0)

        self.relay_vusb_to_dut = self.manager.get_instrument(41)
        self.relay_dusb_to_dut = self.manager.get_instrument(42)
        self.relay_sense = self.manager.get_instrument(43)
        self.relay_fill_supercap = self.manager.get_instrument(44)
        self.relay_drain_supercap = self.manager.get_instrument(45)
        self.relay_supercap_to_dut = self.manager.get_instrument(46)
        self.relay_battery_to_dut = self.manager.get_instrument(47)
        self.voltage_battery_instrument = self.manager.get_instrument(48)
        self.voltage_supercap_instrument = self.manager.get_instrument(49)
        self.current_usb_instrument = self.manager.get_instrument(50)
        self.battery_instrument = self.manager.get_instrument(51)

        self.serial_wire_instruments.append(self.manager.get_instrument(2))
        self.serial_wire_instruments.append(self.manager.get_instrument(3))

        self.storage_instrument = self.manager.get_instrument(4)
        self.file_system = FileSystem(self.storage_instrument)
        self.presenter.log('Inspecting file system...')

        for identifier in range(81, 81 + 28):
            self.gpio_instruments.append(self.manager.get_instrument(identifier))


class Script:

    status_fail = 0
    status_pass = 1
    status_cancelled = 2
    status_exception = 3

    def __init__(self, presenter):
        self.presenter = presenter
        self.status = Script.status_fail

    def setup(self):
        pass

    def main(self):
        self.setup()

    def is_cancelling(self):
        return self.presenter.is_cancelling()

    def completed(self):
        self.presenter.script_completed()

    def log(self, message):
        self.presenter.log(message)


class FixtureScript(Script):

    def __init__(self, presenter, fixture):
        super().__init__(presenter)
        self.fixture = fixture

    def setup(self):
        super().setup()
        self.fixture.setup()

        self.presenter.log('File system entries:')
        entries = self.fixture.file_system.list()
        for entry in entries:
            self.log(f"  {entry.name} {entry.length}")

    def main(self):
        super().main()


class BlinkyScript(FixtureScript):

    def __init__(self, presenter, fixture):
        super().__init__(presenter, fixture)

    def setup(self):
        super().setup()

    def main(self):
        super().main()

        while True:
            self.fixture.indicator_instrument.set(1.0, 0.0, 0.0)
            time.sleep(0.5)
            self.fixture.indicator_instrument.set(0.0, 0.0, 0.1)
            time.sleep(0.5)


class FirmwareRange:

    def __init__(self, address, size):
        self.address = address
        self.size = size


class Firmware:

    def __init__(self, name):
        self.name = name
        self.address = None
        self.data = None
        self.heap = None
        self.stack = None
        self.functions = None
        self.load_elf_from_resource(name)

    def load_symbols(self, elf):
        self.functions = {}
        dwarf = elf.get_dwarf_info()
        if not dwarf.has_debug_info:
            return
        for cu in dwarf.iter_CUs():
            for die in cu.iter_DIEs():
                if die.is_null():
                    continue
                if die.tag == 'DW_TAG_subprogram':
                    name = die.attributes['DW_AT_name'].value.decode('latin-1')
                    address = die.attributes['DW_AT_low_pc'].value
                    self.functions[name] = address

    @staticmethod
    def get_section_range(elf, name):
        section = elf.get_section_by_name(name)
        address = section.header['sh_addr']
        size = section.header['sh_size']
        return FirmwareRange(address, size)

    def load_sections(self, elf):
        # merge .vectors, .init, .text
        data_section_names = ['.vectors', '.init', '.text']
        firmware_address = None
        firmware_end = None
        for name in data_section_names:
            section = elf.get_section_by_name(name)
            address = section.header['sh_addr']
            size = section.header['sh_size']
            end = address + size
            if firmware_address is None:
                firmware_address = address
                firmware_end = end
            else:
                firmware_address = min(firmware_address, address)
                firmware_end = max(firmware_end, end)
        size = firmware_end - firmware_address
        firmware_data = [0] * size
        for name in data_section_names:
            section = elf.get_section_by_name(name)
            address = section.header['sh_addr']
            data = section.data()
            start = address - firmware_address
            end = start + len(data)
            firmware_data[start:end] = data
        self.address = firmware_address
        self.data = firmware_data
        self.heap = self.get_section_range(elf, '.heap')
        self.stack = self.get_section_range(elf, '.stack')

    def load_elf(self, name):
        with open(name, 'rb') as file:
            elf = ELFFile(file)
            self.load_symbols(elf)
            self.load_sections(elf)

    def load_elf_from_resource(self, name):
        bundle = Bundle.get_default_bundle()
        path = bundle.path_for_resource(name)
        self.load_elf(path)

    def __str__(self):
        string = f"code: 0x{self.address:08x} size: 0x{len(self.data):08x}"
        string += f"\nstack: 0x{self.stack.address:08x} size: 0x{self.stack.size:08x}"
        string += f"\nheap: 0x{self.heap.address:08x} size: 0x{self.heap.size:08x}"
        for key, value in self.functions.items():
            string += f"\n{key} @ 0x{value:08x}"
        return string


def bit(n):
    return 1 << n


class SerialWireDebug:
    # Debug Port (DP)

    # Cortex M4
    dpid_cm4 = 0x0ba01477
    # Cortex M3
    dpid_cm3 = 0x2ba01477
    # Cortex M0
    dpid_cm0dap1 = 0x0bb11477
    # Cortex M0+
    dpid_cm0dap2 = 0x0bb12477

    dp_idcode = 0x00
    dp_abort = 0x00
    dp_ctrl = 0x04
    dp_stat = 0x04
    dp_select = 0x08
    dp_rdbuff = 0x0c

    dp_abort_orunerrclr = bit(4)
    dp_abort_wderrclr = bit(3)
    dp_abort_stkerrclr = bit(2)
    dp_abort_stkcmpclr = bit(1)
    dp_abort_dapabort = bit(0)

    dp_ctrl_csyspwrupack = bit(31)
    dp_ctrl_csyspwrupreq = bit(30)
    dp_ctrl_cdbgpwrupack = bit(29)
    dp_ctrl_cdbgpwrupreq = bit(28)
    dp_ctrl_cdbgrstack = bit(27)
    dp_ctrl_cdbgrstreq = bit(26)
    dp_stat_wdataerr = bit(7)
    dp_stat_readok = bit(6)
    dp_stat_stickyerr = bit(5)
    dp_stat_stickycmp = bit(4)
    dp_stat_trnmode = bit(3) | bit(2)
    dp_stat_stickyorun = bit(1)
    dp_stat_orundetect = bit(0)

    dp_select_apsel_apb_ap = 0
    dp_select_apsel_nrf52_ctrl_ap = 1

    # Advanced High - Performance Bus Access Port (AHB_AP or just AP)
    ahb_ap_id_v1 = 0x24770011
    ahb_ap_id_v2 = 0x04770021

    ap_csw = 0x00
    ap_tar = 0x04
    ap_sbz = 0x08
    ap_drw = 0x0c
    ap_bd0 = 0x10
    ap_bd1 = 0x14
    ap_bd2 = 0x18
    ap_bd3 = 0x1c
    ap_dbgdrar = 0xf8
    ap_idr = 0xfc

    @staticmethod
    def idr_code(id):
        return (id >> 17) & 0x7ff

    ap_csw_dbgswenable = bit(31)
    ap_csw_master_debug = bit(29)
    ap_csw_hprot = bit(25)
    ap_csw_spiden = bit(23)
    ap_csw_trin_prog = bit(7)
    ap_csw_device_en = bit(6)
    ap_csw_increment_packed = bit(5)
    ap_csw_increment_single = bit(4)
    ap_csw_32bit = bit(1)
    ap_csw_16bit = bit(0)

    memory_cpuid = 0xe000ed00
    memory_dfsr = 0xe000ed30
    memory_dhcsr = 0xe000edf0
    memory_dcrsr = 0xe000edf4
    memory_dcrdr = 0xe000edf8
    memory_demcr = 0xe000edfc

    dhcsr_dbgkey = 0xa05f0000
    dhcsr_stat_reset_st = bit(25)
    dhcsr_stat_retire_st = bit(24)
    dhcsr_stat_lockup = bit(19)
    dhcsr_stat_sleep = bit(18)
    dhcsr_stat_halt = bit(17)
    dhcsr_stat_regrdy = bit(16)
    dhcsr_ctrl_snapstall = bit(5)
    dhcsr_ctrl_maskints = bit(3)
    dhcsr_ctrl_step = bit(2)
    dhcsr_ctrl_halt = bit(1)
    dhcsr_ctrl_debugen = bit(0)

    def __init__(self, serial_wire_instrument, access_port_id):
        self.serial_wire_instrument = serial_wire_instrument
        self.access_port_id = access_port_id

    def connect(self):
        self.serial_wire_instrument.set_access_port_id(self.access_port_id)
        self.serial_wire_instrument.set_enabled(True)
        time.sleep(0.1)
        self.serial_wire_instrument.set(SerialWireInstrument.outputReset, True)
        time.sleep(0.1)
        self.serial_wire_instrument.set(SerialWireInstrument.outputReset, False)
        time.sleep(0.1)
        return self.serial_wire_instrument.connect()


class CortexM:

    register_r0 = 0
    register_r1 = 1
    register_r2 = 2
    register_r3 = 3
    register_r4 = 4
    register_r5 = 5
    register_r6 = 6
    register_r7 = 7
    register_r8 = 8
    register_r9 = 9
    register_r10 = 10
    register_r11 = 11
    register_r12 = 12
    register_ip = 12
    register_r13 = 13
    register_sp = 13
    register_r14 = 14
    register_lr = 14
    register_r15 = 15
    register_pc = 15
    register_xpsr = 16
    register_msp = 17
    register_psp = 18

    register_s0 = 0x40
    register_s1 = 0x41
    register_s2 = 0x42
    register_s3 = 0x43
    register_s4 = 0x44
    register_s5 = 0x45
    register_s6 = 0x46
    register_s7 = 0x47
    register_s8 = 0x48
    register_s9 = 0x49
    register_s10 = 0x4a
    register_s11 = 0x4b
    register_s12 = 0x4c
    register_s13 = 0x4d
    register_s14 = 0x4e
    register_s15 = 0x4f
    register_s16 = 0x50
    register_s17 = 0x51
    register_s18 = 0x52
    register_s19 = 0x53
    register_s20 = 0x54
    register_s21 = 0x55
    register_s22 = 0x56
    register_s23 = 0x57
    register_s24 = 0x58
    register_s25 = 0x59
    register_s26 = 0x5a
    register_s27 = 0x5b
    register_s28 = 0x5c
    register_s29 = 0x5d
    register_s30 = 0x5e
    register_s31 = 0x5f


def retry(function, timeout, error):
    start = time.time()
    while True:
        if function():
            break
        delta = time.time() - start
        if delta > timeout:
            raise IOError(error)


class SerialWireDebugRemoteProcedureCall:

    def __init__(self, serial_wire_instrument, firmware):
        self.serial_wire_instrument = serial_wire_instrument
        self.firmware = firmware

    def setup(self):
        self.serial_wire_instrument.write_memory(self.firmware.address, self.firmware.data)

    def read_dhcsr(self):
        return self.serial_wire_instrument.read_memory_uint32(SerialWireDebug.memory_dhcsr)

    def run(self, name, r0=0, r1=0, r2=0, r3=0, timeout=1.0):
        dhcsr_halt = SerialWireDebug.dhcsr_dbgkey | SerialWireDebug.dhcsr_ctrl_debugen | SerialWireDebug.dhcsr_ctrl_halt
        dhcsr_run = SerialWireDebug.dhcsr_dbgkey | SerialWireDebug.dhcsr_ctrl_debugen
        function_location = self.firmware.functions[name]
        pc = function_location | 0x00000001
        stack = self.firmware.stack
        sp = stack.address + stack.size
        break_location = self.firmware.functions['halt']
        lr = break_location | 0x00000001
        transfers = [
            SerialWireDebugTransfer.write_memory(SerialWireDebug.memory_dhcsr, dhcsr_halt),
            SerialWireDebugTransfer.write_register(CortexM.register_r0, r0),
            SerialWireDebugTransfer.write_register(CortexM.register_r1, r1),
            SerialWireDebugTransfer.write_register(CortexM.register_r2, r2),
            SerialWireDebugTransfer.write_register(CortexM.register_r3, r3),
            SerialWireDebugTransfer.write_register(CortexM.register_sp, sp),
            SerialWireDebugTransfer.write_register(CortexM.register_pc, pc),
            SerialWireDebugTransfer.write_register(CortexM.register_lr, lr),
            SerialWireDebugTransfer.write_memory(SerialWireDebug.memory_dhcsr, dhcsr_run),
        ]
        self.serial_wire_instrument.transfer(transfers)
        retry(
            lambda: (self.read_dhcsr() & SerialWireDebug.dhcsr_stat_halt) != 0,
            timeout, "SerialWireDebug RPC timeout")
        return self.serial_wire_instrument.read_register(CortexM.register_r0)


class Flasher:

    def __init__(self, serial_wire_instrument, mcu, name, file_system=None):
        self.serial_wire_instrument = serial_wire_instrument
        self.mcu = mcu
        self.name = name
        self.file_system = file_system

        self.rpc = None
        self.firmware = None
        self.entry = None

        if file_system is not None:
            self.transfer_to_ram = self.transfer_to_ram_via_storage
        else:
            self.transfer_to_ram = self.transfer_to_ram_via_swd

    def setup_firmware(self):
        self.firmware = Firmware(f"firmware/{self.name}.elf")
        if self.file_system is not None:
            self.entry = self.file_system.ensure(self.name, self.firmware.data, time.time())

    def setup_rpc(self):
        flasher_firmware = Firmware(f"flasher/{self.mcu}.elf")
        self.rpc = SerialWireDebugRemoteProcedureCall(self.serial_wire_instrument, flasher_firmware)
        self.rpc.setup()

    def setup(self):
        self.setup_firmware()
        self.setup_rpc()

    def erase_all(self):
        result = self.rpc.run('erase_all')
        if result != 0:
            raise IOError(f"Flasher erase_all failed ({result})")

    def erase(self, address, size):
        result = self.rpc.run('erase_page', address, size)
        if result != 0:
            raise IOError(f"Flasher erase_page(0x{address:08x}, 0x{size:08x}) failed ({result})")

    def write(self, address, data, size):
        result = self.rpc.run('write', address, data, size)
        if result != 0:
            raise IOError(f"Flasher write(0x{address:08x}), 0x{data:08x}, 0x{size:08x}) failed ({result})")

    def transfer_to_ram_via_storage(self, address, offset, count):
        storage_identifier = self.entry.storage_instrument.identifier
        storage_address = self.entry.address + offset
        self.rpc.serial_wire_instrument.write_from_storage(address, count, storage_identifier, storage_address)

    def transfer_to_ram_via_swd(self, address, offset, count):
        subdata = self.firmware.data[offset:offset + count]
        self.rpc.serial_wire_instrument.write_memory(address, subdata)

    def program(self):
        assert (self.rpc.firmware.heap.address & 0x7) == 0
        assert (self.rpc.firmware.heap.size & 0x7) == 0
        heap = self.rpc.firmware.heap.address
        max_count = self.rpc.firmware.heap.size
        address = self.firmware.address
        data = self.firmware.data
        subaddress = address
        while True:
            offset = subaddress - address
            count = min(len(data) - offset, max_count)
            if count == 0:
                break
            self.transfer_to_ram(heap, offset, count)
            self.write(subaddress, heap, count)
            subaddress += count


class NRF53:

    access_port_id_application_ahb_ap = 0
    access_port_id_network_ahb_ap = 1
    access_port_id_application_ctrl_ap = 2
    access_port_id_network_ctrl_ap = 3

    ctrl_ap_reset = 0x000
    ctrl_ap_eraseall = 0x004
    ctrl_ap_eraseallstatus = 0x008
    ctrl_ap_approtect_disable = 0x010
    ctrl_ap_secureapprotect_disable = 0x014
    ctrl_ap_eraseprotect_status = 0x018
    ctrl_ap_eraseprotect_disable = 0x01c
    ctrl_ap_mailbox_txdata = 0x020
    ctrl_ap_mailbox_txstatus = 0x024
    ctrl_ap_mailbox_rxdata = 0x028
    ctrl_ap_mailbox_rxstatus = 0x02c
    ctrl_ap_idr = 0x0fc

    def __init__(self, serial_wire_instrument):
        self.serial_wire_instrument = serial_wire_instrument

    def read_erase_all_status(self):
        return self.serial_wire_instrument.read_port(SerialWireDebugTransfer.portAccess, NRF53.ctrl_ap_eraseallstatus)

    def erase_all(self):
        self.serial_wire_instrument.write_port(SerialWireDebugTransfer.portAccess, NRF53.ctrl_ap_eraseall, 1)
        retry(lambda: self.read_erase_all_status() == 0, 1.0, "nRF5340 ctrl ap erase all timeout")


class ProgramScript(FixtureScript):

    def __init__(self, presenter, fixture, mcu, name, serial_wire_instrument_number=0, access_port_id=0):
        super().__init__(presenter, fixture)
        self.mcu = mcu
        self.name = name
        self.serial_wire_instrument_number = serial_wire_instrument_number
        self.access_port_id = access_port_id

    def setup(self):
        super().setup()

        relay_vusb_to_dut = self.fixture.relay_vusb_to_dut
        relay_vusb_to_dut.set(True)

        battery_instrument = self.fixture.battery_instrument
        battery_instrument.set_voltage(3.8)
        battery_instrument.set_enabled(True)
        relay_battery_to_dut = self.fixture.relay_battery_to_dut
        relay_battery_to_dut.set(True)

        storage_instrument = self.fixture.storage_instrument
        storage_instrument.file_mkfs()
        name = "test.bin"
        storage_instrument.file_open(name, StorageInstrument.FA_CREATE_NEW)
        for info in storage_instrument.file_list():
            self.log(f"info: {info.name} {info.size}")
        storage_instrument.file_expand(name, 4096)
        address = storage_instrument.file_address(name)
        data = bytes([0xf0])
        offset = 0
        storage_instrument.file_write(name, offset, data)
        verify = storage_instrument.file_read(name, offset, len(data))
        self.log(f"file: {data} {verify} @ 0x{address:08x}")
        verify = storage_instrument.read(address, len(data))
        self.log(f"storage: {data} {verify}")

        gpio = self.fixture.gpio_instruments[0]
        capabilities = gpio.get_capabilities()
        self.log(f"capabilities: {capabilities}")
        gpio.set_configuration(domain=GpioInstrument.Domain.analog, direction=GpioInstrument.Direction.input)
        voltage = gpio.get_analog_input()
        self.log(f"voltage: {voltage}")

        serial_wire_instrument = self.fixture.serial_wire_instruments[self.serial_wire_instrument_number]
        swd = SerialWireDebug(serial_wire_instrument, self.access_port_id)
        dpid = swd.connect()
        self.log(f"dpid: 0x{dpid:08x}")

    def main(self):
        super().main()

        serial_wire_instrument = self.fixture.serial_wire_instruments[self.serial_wire_instrument_number]
        flasher = Flasher(serial_wire_instrument, self.mcu, self.name, self.fixture.file_system)
        flasher.setup()
        self.log(str(flasher.rpc.firmware))
        flasher.program()

        self.status = Script.status_pass
