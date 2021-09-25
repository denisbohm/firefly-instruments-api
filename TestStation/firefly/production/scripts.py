from enum import Enum
import hashlib
import time
from collections import namedtuple
from .bundle import Bundle
from .instruments import InstrumentManager
from .instruments import SerialWireInstrument
from .instruments import SerialWireDebugTransfer
from .instruments import StorageInstrument
from elftools.elf.elffile import ELFFile
from elftools.elf.constants import SH_FLAGS


class Fixture:

    def __init__(self, presenter):
        self.presenter = presenter
        self.manager = None
        self.indicator_instrument = None
        self.voltage_serial_wire_instruments = []
        self.serial_wire_instruments = []
        self.storage_instrument = None
        self.gpio_instruments = []
        self.gpio_instrument_by_name = {}
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
        self.voltage_serial_wire_instruments.append(self.manager.get_instrument(5))
        self.voltage_serial_wire_instruments.append(self.manager.get_instrument(6))

        self.storage_instrument = self.manager.get_instrument(4)

        gpio_names = [
            "IOA0",
            "IOA1",
            "IOA2",
            "IOA3",
            "IOA4",
            "IOA5",
            "IOA6",
            "IOA7",
            "DIO0",
            "DIO1",
            "DIO2",
            "DIO3",
            "DIO4",
            "DIO5",
            "DIO6",
            "DIO7",
            "DIO8",
            "DIO9",
            "DIO10",
            "DIO11",
            "DIO12",
            "DIO13",
            "DIO14",
            "DIO15",
            "IOR0",
            "IOR1",
            "IOR2",
            "IOR3",
        ]
        index = 0
        for identifier in range(81, 81 + 28):
            instrument = self.manager.get_instrument(identifier)
            self.gpio_instruments.append(instrument)
            name = gpio_names[index]
            self.gpio_instrument_by_name[name] = instrument
            index += 1


class Script:

    status_fail = 0
    status_pass = 1
    status_cancelled = 2
    status_exception = 3

    def __init__(self, presenter):
        self.presenter = presenter
        self.status = Script.status_pass

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

    def __init__(self, name, pad=8):
        self.name = name
        self.address = None
        self.data = None
        self.heap = None
        self.stack = None
        self.functions = None
        self.load_elf_from_resource(name)
        self.pad(pad)

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
                    if 'DW_AT_name' in die.attributes:
                        name = die.attributes['DW_AT_name'].value.decode('latin-1')
                        if 'DW_AT_low_pc' in die.attributes:
                            address = die.attributes['DW_AT_low_pc'].value
                            self.functions[name] = address

    @staticmethod
    def get_section_range(elf, name):
        section = elf.get_section_by_name(name)
        address = section.header['sh_addr']
        size = section.header['sh_size']
        return FirmwareRange(address, size)

    def load_sections(self, elf):
        data_section_names = []
        for section in elf.iter_sections():
            header = section.header
            if (header.sh_flags & SH_FLAGS.SHF_ALLOC) == 0:
                continue
            if header.sh_type == 'SHT_PROGBITS':
                # print(f"copy {section.name} address: 0x{header.sh_addr:08x} size: 0x{header.sh_size:08x}")
                data_section_names.append(section.name)
            elif header.sh_type == 'SHT_NOBITS':
                # print(f"zero {section.name} address: 0x{header.sh_addr:08x} size: 0x{header.sh_size:08x}")
                continue
            else:
                continue

        # merge SHT_PROGBITS sections
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
        try:
            self.heap = self.get_section_range(elf, '.heap')
        except Exception:
            self.heap = self.get_section_range(elf, '.bss.block.heap')
        try:
            self.stack = self.get_section_range(elf, '.stack')
        except Exception:
            self.stack = self.get_section_range(elf, '.bss.block.stack')

    def load_elf(self, name):
        with open(name, 'rb') as file:
            elf = ELFFile(file)
            self.load_symbols(elf)
            self.load_sections(elf)

    def load_elf_from_resource(self, name):
        bundle = Bundle.get_default_bundle()
        path = bundle.path_for_resource(name)
        self.load_elf(path)

    def pad(self, size):
        remainder = len(self.data) % size
        if remainder != 0:
            self.data.extend([0] * (size - remainder))

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

    dp_select_apsel_ahb = 0

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

    ap_csw_dbgswenable    = 0x80000000
    ap_csw_prot           = 0x23000000
    ap_csw_spiden         = 0x00800000
    ap_csw_tr_in_prog     = 0x00000080
    ap_csw_dbg_status     = 0x00000040
    ap_csw_addrinc_single = 0x00000010
    ap_csw_addrinc_off    = 0x00000000
    ap_csw_size_32bit     = 0x00000002
    ap_csw_size_16bit     = 0x00000001
    ap_csw_size_8bit      = 0x00000000

    memory_cpuid = 0xe000ed00
    memory_dfsr  = 0xe000ed30
    memory_dhcsr = 0xe000edf0
    memory_dcrsr = 0xe000edf4
    memory_dcrdr = 0xe000edf8
    memory_demcr = 0xe000edfc

    Field = namedtuple('Field', ['mask', 'name'])

    dhcsr_dbgkey = 0xa05f0000
    dhcsr_stat_restart_st = bit(26)
    dhcsr_stat_reset_st = bit(25)
    dhcsr_stat_retire_st = bit(24)
    dhcsr_stat_fpd = bit(23)
    dhcsr_stat_suide = bit(22)
    dhcsr_stat_nsuide = bit(21)
    dhcsr_stat_sde = bit(20)
    dhcsr_stat_lockup = bit(19)
    dhcsr_stat_sleep = bit(18)
    dhcsr_stat_halt = bit(17)
    dhcsr_stat_regrdy = bit(16)
    dhcsr_ctrl_pmov = bit(6)
    dhcsr_ctrl_snapstall = bit(5)
    dhcsr_ctrl_maskints = bit(3)
    dhcsr_ctrl_step = bit(2)
    dhcsr_ctrl_halt = bit(1)
    dhcsr_ctrl_debugen = bit(0)
    dhcsr_fields = [
        Field(dhcsr_stat_restart_st, "s_restart_st"),
        Field(dhcsr_stat_reset_st, "s_reset_st"),
        Field(dhcsr_stat_retire_st, "s_retire_st"),
        Field(dhcsr_stat_fpd, "s_fpd"),
        Field(dhcsr_stat_suide, "s_suide"),
        Field(dhcsr_stat_nsuide, "s_nsuide"),
        Field(dhcsr_stat_sde, "s_sde"),
        Field(dhcsr_stat_lockup, "s_lockup"),
        Field(dhcsr_stat_sleep, "s_sleep"),
        Field(dhcsr_stat_halt, "s_halt"),
        Field(dhcsr_stat_regrdy, "s_regrdy"),
        Field(dhcsr_ctrl_pmov, "c_pmov"),
        Field(dhcsr_ctrl_snapstall, "c_snapstall"),
        Field(dhcsr_ctrl_maskints, "c_maskints"),
        Field(dhcsr_ctrl_step, "c_step"),
        Field(dhcsr_ctrl_halt, "c_halt"),
        Field(dhcsr_ctrl_debugen, "c_debugen"),
    ]

    def __init__(self, serial_wire_instrument):
        self.serial_wire_instrument = serial_wire_instrument

    @staticmethod
    def dpid_str(dpid):
        revision = (dpid >> 28) & 0xf
        partno = (dpid >> 20) & 0xff
        res0 = (dpid >> 17) & 0x7
        min = (dpid >> 16) & 0x1
        version = (dpid >> 12) & 0xf
        designer = (dpid >> 1) & 0x7ff
        ra0 = (dpid >> 0) & 0x1
        return f"dpid: 0x{dpid:08x}" +\
               f"(revision {revision}, partno {partno}, min {min}, version {version}, designer {designer:03x})"

    def enable_and_reset(self):
        self.serial_wire_instrument.set_enabled(True)
        time.sleep(0.1)
        self.serial_wire_instrument.set(SerialWireInstrument.outputReset, True)
        time.sleep(0.1)
        self.serial_wire_instrument.set(SerialWireInstrument.outputReset, False)
        time.sleep(0.1)

    def is_halted(self):
        dhcsr = self.serial_wire_instrument.read_memory_uint32(SerialWireDebug.memory_dhcsr)
        return (dhcsr & SerialWireDebug.dhcsr_stat_halt) != 0

    def write_dhcsr(self, value):
        value |= SerialWireDebug.dhcsr_dbgkey | SerialWireDebug.dhcsr_ctrl_debugen
        self.serial_wire_instrument.write_memory_uint32(SerialWireDebug.memory_dhcsr, value)

    def halt(self):
        self.write_dhcsr(SerialWireDebug.dhcsr_ctrl_halt)

    def step(self):
        self.write_dhcsr(SerialWireDebug.dhcsr_ctrl_step)

    def run(self):
        self.write_dhcsr(0)


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
        complete = function()
        if complete:
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
        dhcsr = self.serial_wire_instrument.read_memory_uint32(SerialWireDebug.memory_dhcsr)
        return dhcsr

    def get_dump(self):
        dhcsr = self.serial_wire_instrument.read_memory_uint32(SerialWireDebug.memory_dhcsr)
        detail = f"\n @dhcsr = 0x{dhcsr:08x}"
        for field in SerialWireDebug.dhcsr_fields:
            if (dhcsr & field.mask) != 0:
                detail += " " + field.name
        dhcsr_halt = SerialWireDebug.dhcsr_dbgkey | SerialWireDebug.dhcsr_ctrl_debugen | SerialWireDebug.dhcsr_ctrl_halt
        self.serial_wire_instrument.write_memory_uint32(SerialWireDebug.memory_dhcsr, dhcsr_halt)
        transfers = [
            SerialWireDebugTransfer.read_register(CortexM.register_r0),
            SerialWireDebugTransfer.read_register(CortexM.register_r1),
            SerialWireDebugTransfer.read_register(CortexM.register_r2),
            SerialWireDebugTransfer.read_register(CortexM.register_r3),
            SerialWireDebugTransfer.read_register(CortexM.register_sp),
            SerialWireDebugTransfer.read_register(CortexM.register_lr),
            SerialWireDebugTransfer.read_register(CortexM.register_pc),
        ]
        self.serial_wire_instrument.transfer(transfers)
        for transfer in transfers:
            if transfer.type == SerialWireDebugTransfer.typeReadRegister:
                detail += f"\n r{transfer.register} = 0x{transfer.data:08x}"
            elif transfer.type == SerialWireDebugTransfer.typeReadMemory:
                detail += f"\n @0x{transfer.address:08x} = 0x{transfer.data:08x}"
        return detail

    def run(self, name, r0=0, r1=0, r2=0, r3=0, timeout=1.0):
        dhcsr_halt = SerialWireDebug.dhcsr_dbgkey | SerialWireDebug.dhcsr_ctrl_debugen | SerialWireDebug.dhcsr_ctrl_halt
        dhcsr_run = SerialWireDebug.dhcsr_dbgkey | SerialWireDebug.dhcsr_ctrl_debugen
        pc = self.firmware.functions[name]
        stack = self.firmware.stack
        sp = stack.address + stack.size
        break_location = self.firmware.functions['fd_flasher_halt']
        lr = break_location | 0x00000001
        transfers = [
            SerialWireDebugTransfer.write_memory(SerialWireDebug.memory_dhcsr, dhcsr_halt),
            SerialWireDebugTransfer.write_register(CortexM.register_r0, r0),
            SerialWireDebugTransfer.write_register(CortexM.register_r1, r1),
            SerialWireDebugTransfer.write_register(CortexM.register_r2, r2),
            SerialWireDebugTransfer.write_register(CortexM.register_r3, r3),
            SerialWireDebugTransfer.write_register(CortexM.register_sp, sp),
            SerialWireDebugTransfer.write_register(CortexM.register_lr, lr),
            SerialWireDebugTransfer.write_register(CortexM.register_pc, pc),
            SerialWireDebugTransfer.write_memory(SerialWireDebug.memory_dhcsr, dhcsr_run),
        ]
        self.serial_wire_instrument.transfer(transfers)
        try:
            retry(
                lambda: (self.read_dhcsr() & SerialWireDebug.dhcsr_stat_halt) != 0,
                timeout, "SerialWireDebug RPC timeout")
        except Exception as exception:
            raise IOError(str(exception) + self.get_dump())
        return self.serial_wire_instrument.read_register(CortexM.register_r0)


class Flasher:

    def __init__(self, presenter, serial_wire_instrument, mcu, name, storage_instrument=None, filename=None):
        self.presenter = presenter
        self.serial_wire_instrument = serial_wire_instrument
        self.mcu = mcu
        self.name = name
        self.storage_instrument = storage_instrument
        self.filename = filename

        self.rpc = None
        self.firmware = None
        self.file_address = None

        if self.storage_instrument is not None:
            self.transfer_to_ram = self.transfer_to_ram_via_storage
        else:
            self.transfer_to_ram = self.transfer_to_ram_via_swd

    def setup_firmware(self):
        self.firmware = Firmware(f"firmware/{self.name}.elf")
        if self.storage_instrument is None:
            return

        storage_instrument = self.storage_instrument
        for info in storage_instrument.file_list():
            if info.name == self.filename:
                address = storage_instrument.file_address(self.filename)
                storage_hash = bytes(storage_instrument.hash(address, info.size))
                firmware_hash = hashlib.sha1(bytes(self.firmware.data)).digest()
                if storage_hash == firmware_hash:
                    self.file_address = address
                    return
                else:
                    break

        storage_instrument.file_open(self.filename, StorageInstrument.FA_CREATE_ALWAYS)
        storage_instrument.file_expand(self.filename, len(self.firmware.data))
        self.file_address = storage_instrument.file_address(self.filename)
        storage_instrument.file_write(self.filename, 0, self.firmware.data)

    def setup_rpc(self):
        flasher_firmware = Firmware(f"flasher/{self.mcu}.elf")
        self.rpc = SerialWireDebugRemoteProcedureCall(self.serial_wire_instrument, flasher_firmware)
        self.rpc.setup()

    def setup(self):
        self.setup_rpc()
        self.setup_firmware()

    def erase_all(self):
        result = self.rpc.run('fd_flasher_erase_all')
        if result != 0:
            raise IOError(f"flasher erase_all failed ({result})")

    def erase(self, address, size):
        result = self.rpc.run('fd_flasher_erase_page', address, size)
        if result != 0:
            raise IOError(f"flasher erase_page(0x{address:08x}, 0x{size:08x}) failed ({result})")

    def write(self, address, data, size):
        result = self.rpc.run('fd_flasher_write', address, data, size)
        if result != 0:
            raise IOError(f"flasher write(0x{address:08x}), 0x{data:08x}, 0x{size:08x}) failed ({result})")

    def transfer_to_ram_via_storage(self, address, offset, count):
        storage_identifier = self.storage_instrument.identifier
        storage_address = self.file_address + offset
        self.rpc.serial_wire_instrument.write_from_storage(address, count, storage_identifier, storage_address)

    def transfer_to_ram_via_swd(self, address, offset, count):
        subdata = self.firmware.data[offset:offset + count]
        self.rpc.serial_wire_instrument.write_memory(address, subdata)

    def flash(self):
        assert (self.rpc.firmware.heap.address & 0x7) == 0
        assert (self.rpc.firmware.heap.size & 0x7) == 0
        assert (len(self.rpc.firmware.data) & 0x7) == 0
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

    def verify(self):
        address = self.firmware.address
        count = len(self.firmware.data)
        use_storage = True
        if use_storage and (self.storage_instrument is not None):
            code = self.rpc.serial_wire_instrument.compare_to_storage(
                address, count, self.storage_instrument.identifier, self.file_address
            )
            if code != 0:
                raise IOError("firmware verification failed")
        else:
            data = self.rpc.serial_wire_instrument.read_memory(address, count)
            if data != self.firmware.data:
                mismatches = 0
                for i in range(count):
                    vi = data[i]
                    di = self.firmware.data[i]
                    if vi != di:
                        mismatches += 1
                raise IOError("firmware verification failed")

    def program(self):
        self.setup()
        self.flash()
        self.verify()


class SOC:

    class IO:

        def __init__(self, port, pin):
            self.port = port
            self.pin = pin

    def __init__(self, serial_wire_instrument):
        self.serial_wire_instrument = serial_wire_instrument

    def configure_default(self, io):
        transactions = []
        self.append_configure_default_transactions(transactions, io)
        self.serial_wire_instrument.transfer(transactions)

    def append_configure_default_transactions(self, transactions, io):
        raise IOError("unimplemented")

    def configure_output(self, io, value):
        transactions = []
        self.append_configure_output_transactions(transactions, io, value)
        self.serial_wire_instrument.transfer(transactions)

    def append_configure_output_transactions(self, transactions, io, value):
        raise IOError("unimplemented")

    def configure_output_open_drain(self, io, value):
        transactions = []
        self.append_configure_output_open_drain_transactions(transactions, io, value)
        self.serial_wire_instrument.transfer(transactions)

    def append_configure_output_open_drain_transactions(self, transactions, io, value):
        raise IOError("unimplemented")

    def set_output(self, io, value):
        transactions = []
        self.append_set_output_transactions(transactions, io, value)
        self.serial_wire_instrument.transfer(transactions)

    def append_set_output_transactions(self, transactions, io, value):
        raise IOError("unimplemented")

    def configure_input(self, io):
        transactions = []
        self.append_configure_input_transactions(transactions, io)
        self.serial_wire_instrument.transfer(transactions)

    def append_configure_input_transactions(self, transactions, io):
        raise IOError("unimplemented")

    def get_input(self, io):
        transactions = []
        get = self.append_get_input_transactions(transactions, io)
        self.serial_wire_instrument.transfer(transactions)
        return get()

    def append_get_input_transactions(self, transactions, io):
        raise IOError("unimplemented")


class KL0(SOC):

    mcu = "KL0"

    dpid = 0x0BC11477

    dp_select_apsel_ahb = 0
    dp_select_apsel_mdm = 1

    mdm_ap_status = 0x00
    mdm_ap_control = 0x04
    mdm_ap_idr = 0xfc

    mdm_ap_control_flash_mass_erase = 0x00000001
    mdm_ap_control_debug_request = 0x00000004
    mdm_ap_control_system_reset_request = 0x00000008

    ap_idr_ahb = 0x04770031
    ap_idr_mdm = 0x001c0020

    class SIM:

        def __init__(self):
            self.r_SCGC5 = 0x40048038

    class OSC:

        def __init__(self):
            self.r_CR = 0x40065000

    class TPM:

        def __init__(self, base):
            self.r_SC     = base + 0x000  # Status and Control (TPM0_SC) 32 R/W 0000_0000h 31.4.1/465
            self.r_CNT    = base + 0x004  # Counter (TPM0_CNT) 32 R/W 0000_0000h 31.4.2/466
            self.r_MOD    = base + 0x008  # Modulo (TPM0_MOD) 32 R/W 0000_FFFFh 31.4.3/467
            self.r_C0SC   = base + 0x00C  # Channel (n) Status and Control (TPM0_C0SC) 32 R/W 0000_0000h 31.4.4/468
            self.r_C0V    = base + 0x010  # Channel (n) Value (TPM0_C0V) 32 R/W 0000_0000h 31.4.5/469
            self.r_C1SC   = base + 0x014  # Channel (n) Status and Control (TPM0_C1SC) 32 R/W 0000_0000h 31.4.4/468
            self.r_C1V    = base + 0x018  # Channel (n) Value (TPM0_C1V) 32 R/W 0000_0000h 31.4.5/469
            self.r_STATUS = base + 0x050  # Capture and Compare Status (TPM0_STATUS) 32 R/W 0000_0000h 31.4.6/470
            self.r_CONF   = base + 0x084  # Configuration (TPM0_CONF)

    class PORT:
        def __init__(self, base):
            self.r_pcr = []
            for i in range(32):
                self.r_pcr.append(base + 0x000 + i * 4)
            self.r_gpclr = base + 0x080
            self.r_gpchr = base + 0x084
            self.r_isfr = base + 0x0a0

    class FGPIO:

        def __init__(self, base):
            self.r_pdor = base + 0x000
            self.r_psor = base + 0x004
            self.r_pcor = base + 0x008
            self.r_ptor = base + 0x00C
            self.r_pdir = base + 0x010
            self.r_pddr = base + 0x014

    def __init__(self, serial_wire_instrument):
        super().__init__(serial_wire_instrument)
        self.sim = KL0.SIM()
        self.osc = KL0.OSC()
        self.tpm0 = KL0.TPM(0x40038000)
        self.tpm1 = KL0.TPM(0x40039000)
        self.tpm = [self.tpm0, self.tpm1]
        self.porta = KL0.PORT(0x40049000)
        self.portb = KL0.PORT(0x4004A000)
        self.port = [self.porta, self.portb]
        self.fgpioa = KL0.FGPIO(0xF8000000)
        self.fgpiob = KL0.FGPIO(0xF8000040)
        self.fgpio = [self.fgpioa, self.fgpiob]
        self.pddr = 0

    def select_ahb(self):
        self.serial_wire_instrument.set_access_port_id(KL0.dp_select_apsel_ahb)
        idr = self.serial_wire_instrument.select_and_read_access_port(SerialWireDebug.ap_idr)
        if idr != KL0.ap_idr_ahb:
            raise IOError("unexpected ahb idr value")

    def select_mdm(self):
        self.serial_wire_instrument.set_access_port_id(KL0.dp_select_apsel_mdm)
        idr = self.serial_wire_instrument.select_and_read_access_port(SerialWireDebug.ap_idr)
        if idr != KL0.ap_idr_mdm:
            raise IOError("unexpected mdm idr value")

    def reset(self):
        self.select_mdm()
        self.serial_wire_instrument.select_and_write_access_port(KL0.mdm_ap_control,
                                                                 KL0.mdm_ap_control_system_reset_request)
        self.serial_wire_instrument.select_and_write_access_port(KL0.mdm_ap_control, 0)

    def is_erase_complete(self):
        control = self.serial_wire_instrument.select_and_read_access_port(KL0.mdm_ap_control)
        return (control & KL0.mdm_ap_control_flash_mass_erase) == 0

    def erase_all(self):
        self.serial_wire_instrument.set(SerialWireInstrument.outputReset, True)
        self.select_mdm()
        self.reset()
        self.serial_wire_instrument.select_and_write_access_port(KL0.mdm_ap_control,
                                                                 KL0.mdm_ap_control_flash_mass_erase)
        retry(lambda: self.is_erase_complete(), 1.0, "KL0 mdm ap erase all timeout")
        self.serial_wire_instrument.set(SerialWireInstrument.outputReset, False)
        self.serial_wire_instrument.select_and_write_access_port(KL0.mdm_ap_control, KL0.mdm_ap_control_debug_request)
        self.serial_wire_instrument.select_and_write_access_port(KL0.mdm_ap_control, 0)

    def initialize_ahb(self):
        self.select_ahb()
        self.serial_wire_instrument.select_and_write_access_port(
            SerialWireDebug.ap_csw,
            SerialWireDebug.ap_csw_prot |
            SerialWireDebug.ap_csw_addrinc_single |
            SerialWireDebug.ap_csw_size_32bit
        )
        halt = SerialWireDebug.dhcsr_dbgkey | SerialWireDebug.dhcsr_ctrl_debugen | SerialWireDebug.dhcsr_ctrl_halt
        self.serial_wire_instrument.write_memory_uint32(SerialWireDebug.memory_dhcsr, halt)

        # enable port a and b
        scgc5 = self.serial_wire_instrument.read_memory_uint32(self.sim.r_SCGC5)
        scgc5 |= 0x600
        self.serial_wire_instrument.write_memory_uint32(self.sim.r_SCGC5, scgc5)

    def start_counter(self):
        osc = self.osc
        # enable external reference clock
        self.serial_wire_instrument.write_memory_uint32(osc.r_CR, 0xa0)

        tpm = self.tpm0
        # increment on every TPM counter clock
        self.serial_wire_instrument.write_memory_uint32(tpm.r_SC, 0x00000008)
        self.serial_wire_instrument.write_memory_uint32(tpm.r_CNT, 0x00000000)
        self.serial_wire_instrument.write_memory_uint32(tpm.r_MOD, 0x0000ffff)
        # Counter Stop On Overflow, counter continues in debug mode
        self.serial_wire_instrument.write_memory_uint32(tpm.r_CONF, 0x000200c0)
        # Input Capture on Rising Edge
        self.serial_wire_instrument.write_memory_uint32(tpm.r_C0SC, 0x00000004)

    def get_count(self):
        tpm = self.tpm0
        cnt = self.serial_wire_instrument.read_memory_uint32(tpm.r_CNT)
        return cnt

    def append_configure_io_transactions(self, transactions, io, output=False, connected=True, pullup=False):
        self.append_set_output_transactions(transactions, io, output)

        fgpio = self.fgpio[io.port]
        if output:
            self.pddr = self.pddr | (1 << io.pin)
        else:
            self.pddr = self.pddr & ~(1 << io.pin)
        transactions.append(SerialWireDebugTransfer.write_memory(fgpio.r_pddr, self.pddr))

        port = self.port[io.port]
        pcr = 0x00000100 if connected else 0x00000000
        if pullup:
            pcr |= 0b11
        transactions.append(SerialWireDebugTransfer.write_memory(port.r_pcr[io.pin], pcr))

    def append_configure_default_transactions(self, transactions, io):
        self.append_configure_io_transactions(transactions, io, connected=False)

    def append_configure_output_transactions(self, transactions, io, value):
        self.append_configure_io_transactions(transactions, io, output=True)
        self.append_set_output_transactions(transactions, io, value)

    def append_configure_output_open_drain_transactions(self, transactions, io, value):
        raise IOError("unimplemented")

    def append_set_output_transactions(self, transactions, io, value):
        fgpio = self.fgpio[io.port]
        address = fgpio.r_psor if value else fgpio.r_pcor
        transactions.append(SerialWireDebugTransfer.write_memory(address, 1 << io.pin))

    def append_configure_input_transactions(self, transactions, io):
        self.append_configure_io_transactions(transactions, io, output=False)

    def append_get_input_transactions(self, transactions, io):
        fgpio = self.fgpio[io.port]
        transaction = SerialWireDebugTransfer.read_memory(fgpio.r_pdir)
        transactions.append(transaction)
        return lambda: (transaction.data & (1 << io.pin)) != 0


class NRF53(SOC):

    mcu_app = "nrf53_app"
    mcu_net = "nrf53_net"

    dpid = 0x6BA02477

    dp_select_apsel_ahb_app = 0
    dp_select_apsel_ahb_net = 1
    dp_select_apsel_ctrl_app = 2
    dp_select_apsel_ctrl_net = 3

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

    ap_idr_ahb = 0x84770001
    ap_idr_ctrl = 0x12880000

    reset_network_forceoff = 0x50005614

    class GPIO:

        def __init__(self, base):
            self.r_out = base + 0x004
            self.r_outset = base + 0x008
            self.r_outclr = base + 0x00c
            self.r_in = base + 0x010
            self.r_dir = base + 0x014
            self.r_dirset = base + 0x018
            self.r_dirclr = base + 0x01c
            self.r_pin_cnf = []
            for i in range(32):
                self.r_pin_cnf.append(base + 0x200 + (i * 0x4))

    class FICR:

        def __init__(self):
            base = 0x00FF0000
            self.r_xosc32mtrim = base + 0xC20

    class UICR:

        def __init__(self):
            base = 0x00FF8000
            self.r_nfcpins = base + 0x028

    class CLOCK:

        def __init__(self, base):
            self.r_tasks_hfclkstart = base + 0x000
            self.r_tasks_lfclkstart = base + 0x008
            self.r_events_hfclkstarted = base + 0x100
            self.r_events_lfclkstarted = base + 0x104
            self.r_hfclkrun = base + 0x408
            self.r_hfclkstat = base + 0x40C
            self.r_lfclkrun = base + 0x414
            self.r_lfclkstat = base + 0x418
            self.r_hfclksrc = base + 0x514
            self.r_lfclksrc = base + 0x518
            self.r_hfclkalwaysrun = base + 0x570
            self.r_lfclkalwaysrun = base + 0x574

    class OSCILLATORS:

        def __init__(self, base):
            self.r_xosc32mcaps = base + 0x5C4
            self.r_xosc32ki_bypass = base + 0x6C0
            self.r_xosc32ki_intcap = base + 0x6D0

    class Application:

        def __init__(self):
            self.ficr = NRF53.FICR()
            self.uicr = NRF53.UICR()
            self.p0_s = NRF53.GPIO(0x50842500)
            self.p1_s = NRF53.GPIO(0x50842800)
            self.p_s = [self.p0_s, self.p1_s]
            self.clock_s = NRF53.CLOCK(0x50005000)
            self.oscillators_s = NRF53.OSCILLATORS(0x50004000)

    def __init__(self, serial_wire_instrument):
        super().__init__(serial_wire_instrument)
        self.application = NRF53.Application()

    def select_ahb(self, ahb):
        self.serial_wire_instrument.set_access_port_id(ahb)
        idr = self.serial_wire_instrument.select_and_read_access_port(SerialWireDebug.ap_idr)
        if idr != NRF53.ap_idr_ahb:
            raise IOError("unexpected ahb idr value")

    def select_ctrl(self, ctrl):
        self.serial_wire_instrument.set_access_port_id(ctrl)
        idr = self.serial_wire_instrument.select_and_read_access_port(SerialWireDebug.ap_idr)
        if idr != NRF53.ap_idr_ctrl:
            raise IOError("unexpected ctrl idr value")

    def reset(self):
        self.select_ctrl(NRF53.dp_select_apsel_ctrl_app)
        self.serial_wire_instrument.select_and_write_access_port(NRF53.ctrl_ap_reset, 0x00000001)
        self.serial_wire_instrument.select_and_write_access_port(NRF53.ctrl_ap_reset, 0x00000000)

    def read_erase_all_status(self):
        return self.serial_wire_instrument.select_and_read_access_port(NRF53.ctrl_ap_eraseallstatus)

    def erase_all(self):
        self.serial_wire_instrument.select_and_write_access_port(NRF53.ctrl_ap_eraseall, 0x00000001)
        retry(lambda: self.read_erase_all_status() == 0, 1.0, "nRF5340 ctrl ap erase all timeout")

    def initialize_ahb(self, ahb):
        self.select_ahb(ahb)
        self.serial_wire_instrument.select_and_write_access_port(
            SerialWireDebug.ap_csw,
            SerialWireDebug.ap_csw_prot |
            SerialWireDebug.ap_csw_addrinc_single |
            SerialWireDebug.ap_csw_size_32bit
        )
        halt = SerialWireDebug.dhcsr_dbgkey | SerialWireDebug.dhcsr_ctrl_debugen | SerialWireDebug.dhcsr_ctrl_halt
        self.serial_wire_instrument.write_memory_uint32(SerialWireDebug.memory_dhcsr, halt)

    def release_network_forceoff(self):
        reset_network_forceoff = self.serial_wire_instrument.read_memory_uint32(NRF53.reset_network_forceoff)
        if reset_network_forceoff != 0:
            self.serial_wire_instrument.write_memory_uint32(NRF53.reset_network_forceoff, 0)
            reset_network_forceoff = self.serial_wire_instrument.read_memory_uint32(NRF53.reset_network_forceoff)
            if reset_network_forceoff != 0:
                raise IOError("Cannot release RESET.NETWORK.FORCEOFF")

    def recover(self):
        self.select_ctrl(NRF53.dp_select_apsel_ctrl_app)
        self.erase_all()

        self.select_ctrl(NRF53.dp_select_apsel_ctrl_net)
        self.erase_all()

        self.initialize_ahb(NRF53.dp_select_apsel_ahb_app)
        # See nRF5340 Production Programming nAN42 -denis
        self.release_network_forceoff()

    def append_configure_default_transactions(self, transactions, io):
        self.append_configure_input_transactions(transactions, io)

    def append_configure_output_transactions(self, transactions, io, value):
        p_s = self.application.p_s[io.port]
        pin_cnf = p_s.r_pin_cnf[io.pin]
        transactions.append(SerialWireDebugTransfer.write_memory(pin_cnf, 0x00000001))
        self.append_set_output_transactions(transactions, io, value)

    def append_configure_output_open_drain_transactions(self, transactions, io, value):
        p_s = self.application.p_s[io.port]
        pin_cnf = p_s.r_pin_cnf[io.pin]
        transactions.append(SerialWireDebugTransfer.write_memory(pin_cnf, 0x00000601))
        self.append_set_output_transactions(transactions, io, value)

    def append_set_output_transactions(self, transactions, io, value):
        p_s = self.application.p_s[io.port]
        address = p_s.r_outset if value else p_s.r_outclr
        data = 1 << io.pin
        transactions.append(SerialWireDebugTransfer.write_memory(address, data))

    def append_configure_input_transactions(self, transactions, io):
        p_s = self.application.p_s[io.port]
        pin_cnf = p_s.r_pin_cnf[io.pin]
        transactions.append(SerialWireDebugTransfer.write_memory(pin_cnf, 0x00000000))

    def append_get_input_transactions(self, transactions, io):
        p_s = self.application.p_s[io.port]
        transaction = SerialWireDebugTransfer.read_memory(p_s.r_in)
        transactions.append(transaction)
        return lambda: (transaction.data & (1 << io.pin)) != 0

    def read_events_lfclkstarted(self):
        clock_s = self.application.clock_s
        events_lfclkstarted = self.serial_wire_instrument.read_memory_uint32(clock_s.r_events_lfclkstarted)
        return events_lfclkstarted

    def start_lfclk(self, capacitance=6):
        p_s = self.application.p0_s
        for pin in range(2):
            pin_cnf = p_s.r_pin_cnf[pin]
            self.serial_wire_instrument.write_memory_uint32(pin_cnf, 0x30000002)

        oscillators_s = self.application.oscillators_s
        if capacitance == 0:
            intcap = 0
        elif capacitance <= 6:
            intcap = 1
        elif capacitance <= 7:
            intcap = 2
        else:
            intcap = 3
        self.serial_wire_instrument.write_memory_uint32(oscillators_s.r_xosc32ki_intcap, intcap)

        clock_s = self.application.clock_s
        self.serial_wire_instrument.write_memory_uint32(clock_s.r_lfclksrc, 0x00000002)
        self.serial_wire_instrument.write_memory_uint32(clock_s.r_lfclkalwaysrun, 0x00000001)
        self.serial_wire_instrument.write_memory_uint32(clock_s.r_events_lfclkstarted, 0x00000000)
        self.serial_wire_instrument.write_memory_uint32(clock_s.r_tasks_lfclkstart, 0x00000001)

        retry(
            lambda: self.read_events_lfclkstarted() == 0x00000001,
            1.0, "32.768 kHz clock startup timeout")
        lfclkstat = self.serial_wire_instrument.read_memory_uint32(clock_s.r_lfclkstat)
        if lfclkstat != 0x00010012:
            raise IOError("32.768 kHz clock unexpected status")

    def read_events_hfclkstarted(self):
        clock_s = self.application.clock_s
        events_hfclkstarted = self.serial_wire_instrument.read_memory_uint32(clock_s.r_events_hfclkstarted)
        return events_hfclkstarted

    def start_hfclk(self, capacitance=9.5):
        ficr = self.application.ficr
        xosc32mtrim = self.serial_wire_instrument.read_memory_uint32(ficr.r_xosc32mtrim)
        offset = xosc32mtrim & 0x1f
        slope = (xosc32mtrim >> 5) & 0x1f
        capvalue = int(((slope + 56) * (capacitance * 2 - 14)) + ((offset - 8) << 4) + 32) >> 6
        oscillators_s = self.application.oscillators_s
        self.serial_wire_instrument.write_memory_uint32(oscillators_s.r_xosc32mcaps, 0x00000100 | capvalue)

        clock_s = self.application.clock_s
        self.serial_wire_instrument.write_memory_uint32(clock_s.r_hfclksrc, 0x00000001)
        self.serial_wire_instrument.write_memory_uint32(clock_s.r_hfclkalwaysrun, 0x00000001)
        self.serial_wire_instrument.write_memory_uint32(clock_s.r_events_hfclkstarted, 0x00000000)
        self.serial_wire_instrument.write_memory_uint32(clock_s.r_tasks_hfclkstart, 0x00000001)
        retry(
            lambda: self.read_events_hfclkstarted() == 0x00000001,
            1.0, "32 MHz clock startup timeout")
        hfclkstat = self.serial_wire_instrument.read_memory_uint32(clock_s.r_hfclkstat)
        if hfclkstat != 0x00010011:
            raise IOError("32 MHz clock unexpected status")


class I2CM:

    class Device:

        def __init__(self, address):
            self.address = address

    class Direction(Enum):
        tx = 0
        rx = 1

    class Transfer:

        def __init__(self, direction, data=None, count=0):
            self.direction = direction
            self.data = data
            self.count = count

        @staticmethod
        def tx(data):
            return I2CM.Transfer(I2CM.Direction.tx, data=data)

        @staticmethod
        def rx(count):
            return I2CM.Transfer(I2CM.Direction.rx, count=count)

    class IO:

        def __init__(self, transfers):
            self.transfers = transfers

    def __init__(self, soc, scl, sda):
        self.soc = soc
        self.scl = scl
        self.sda = sda

    def delay(self):
        pass

    """
    def configure_in(self):
        self.soc.configure_input(self.sda)

    def configure_out(self):
        self.soc.configure_output_open_drain(self.sda, True)

    def set_scl(self, value: bool):
        self.soc.set_output(self.scl, value)

    def set_sda(self, value: bool):
        self.soc.set_output(self.sda, value)

    def get_sda(self) -> bool:
        return self.soc.get_input(self.sda)
    """

    def clear_bus(self, transactions):
        # self.set_scl(True)
        self.soc.append_set_output_transactions(transactions, self.scl, True)
        # self.set_sda(True)
        self.soc.append_set_output_transactions(transactions, self.sda, True)
        self.delay()
        for _ in range(9):
            # self.set_scl(False)
            self.soc.append_set_output_transactions(transactions, self.scl, False)
            self.delay()
            # self.set_scl(True)
            self.soc.append_set_output_transactions(transactions, self.scl, True)
            self.delay()

    def start(self):
        transactions = []
        # self.set_scl(True)
        self.soc.append_set_output_transactions(transactions, self.scl, True)
        # self.set_sda(True)
        self.soc.append_set_output_transactions(transactions, self.sda, True)
        self.delay()
        # self.set_sda(False)
        self.soc.append_set_output_transactions(transactions, self.sda, False)
        self.delay()
        # self.set_scl(False)
        self.soc.append_set_output_transactions(transactions, self.scl, False)
        self.delay()
        self.soc.serial_wire_instrument.transfer(transactions)
    
    def stop(self):
        transactions = []
        # self.set_sda(False)
        self.soc.append_set_output_transactions(transactions, self.sda, False)
        self.delay()
        # self.set_scl(True)
        self.soc.append_set_output_transactions(transactions, self.scl, True)
        self.delay()
        # self.set_sda(True)
        self.soc.append_set_output_transactions(transactions, self.sda, True)
        self.delay()
        self.soc.serial_wire_instrument.transfer(transactions)

    def write_bit(self, transactions, bit: bool):
        # self.set_sda(bit)
        self.soc.append_set_output_transactions(transactions, self.sda, bit)
        self.delay()
        # self.set_scl(True)
        self.soc.append_set_output_transactions(transactions, self.scl, True)
        self.delay()
        # self.set_scl(False)
        self.soc.append_set_output_transactions(transactions, self.scl, False)

    def read_bit(self, transactions):
        # self.set_sda(True)
        self.soc.append_set_output_transactions(transactions, self.sda, True)
        self.delay()
        # self.set_scl(True)
        self.soc.append_set_output_transactions(transactions, self.scl, True)
        self.delay()
        # bit = self.get_sda()
        get = self.soc.append_get_input_transactions(transactions, self.sda)
        # self.set_scl(False)
        self.soc.append_set_output_transactions(transactions, self.scl, False)
        return get
    
    def write_byte(self, byte) -> bool:
        transactions = []
        for _ in range(8):
            self.write_bit(transactions, (byte & 0x80) != 0)
            byte <<= 1
    
        # self.set_sda(True)
        self.soc.append_set_output_transactions(transactions, self.sda, True)
        # self.configure_in()
        self.soc.append_configure_input_transactions(transactions, self.sda)
        get_ack = self.read_bit(transactions)
        # self.configure_out(transactions)
        self.soc.append_configure_output_open_drain_transactions(transactions, self.sda, True)
        self.soc.serial_wire_instrument.transfer(transactions)
        ack = get_ack()
        return ack is False
    
    def read_byte(self, ack: bool) -> int:
        transactions = []
        # self.configure_in()
        self.soc.append_configure_input_transactions(transactions, self.sda)
        get_bits = []
        for _ in range(8):
            get_bits.append(self.read_bit(transactions))
        # self.configure_out()
        self.soc.append_configure_output_open_drain_transactions(transactions, self.sda, True)
        self.write_bit(transactions, not ack)
        self.soc.serial_wire_instrument.transfer(transactions)
        byte = 0
        for i in range(8):
            get_bit = get_bits[i]
            bit = get_bit()
            byte = (byte << 1) | (1 if bit else 0)
        return byte
    
    def bus_tx(self, bytes) -> bool:
        for byte in bytes:
            ack = self.write_byte(byte)
            if not ack:
                return False
        return True

    def bus_rx(self, count: int, ack: bool):
        bytes = []
        for i in range(count):
            byte = self.read_byte(ack or (i < (count - 1)))
            bytes.append(byte)
        return bytes

    def start_write(self, device):
        self.start()
        return self.write_byte(device.address << 1)
    
    def start_read(self, device) -> bool:
        self.start()
        return self.write_byte((device.address << 1) | 1)
    
    def device_io(self, device, io) -> bool:
        last_direction = -1
        ack = True
        try:
            for i in range(len(io.transfers)):
                transfer = io.transfers[i]
                if transfer.direction == I2CM.Direction.tx:
                    if transfer.direction != last_direction:
                        ack = self.start_write(device)
                        if not ack:
                            raise IOError("I2C nack")
                    ack = self.bus_tx(transfer.data)
                    if not ack:
                        raise IOError("I2C nack")
                elif transfer.direction == I2CM.Direction.rx:
                    if transfer.direction != last_direction:
                        ack = self.start_read(device)
                        if not ack:
                            raise IOError("I2C nack")
                    rx_ack = (i < len(io.transfers) - 1) and (io.transfers[i + 1].direction == I2CM.Direction.rx)
                    transfer.data = self.bus_rx(transfer.count, rx_ack)
                last_direction = transfer.direction
        except IOError:
            pass
        self.stop()
        return ack
    
    def initialize(self):
        transactions = []
        self.soc.append_configure_output_open_drain_transactions(transactions, self.scl, True)
        self.soc.append_configure_output_open_drain_transactions(transactions, self.sda, True)
        self.clear_bus(transactions)
        self.soc.serial_wire_instrument.transfer(transactions)

    def read_register(self, device, address) -> int:
        rx = I2CM.Transfer.rx(1)
        io = I2CM.IO([I2CM.Transfer.tx([address]), rx])
        ack = self.device_io(device, io)
        if not ack:
            raise IOError("I2C nack")
        return rx.data[0]

    def write_register(self, device, address, value):
        io = I2CM.IO([I2CM.Transfer.tx([address, value])])
        ack = self.device_io(device, io)
        if not ack:
            raise IOError("I2C nack")


class SPI:

    def __init__(self, soc, csn, c, d0, d1=None, d2=None, d3=None):
        super().__init__()
        self.soc = soc
        self.csn = csn
        self.c = c
        self.d0 = d0
        self.d1 = d1
        self.d2 = d2
        self.d3 = d3

    def configure_dq_as_single(self):
        self.soc.configure_output(self.d0, True)
        if self.d1 is not None:
            self.soc.configure_input(self.d1)
        if self.d2 is not None:
            self.soc.configure_output(self.d2, True)
        if self.d3 is not None:
            self.soc.configure_output(self.d3, True)

    def configure_dq_as_quad_input(self):
        self.soc.configure_input(self.d0)
        self.soc.configure_input(self.d1)
        self.soc.configure_input(self.d2)
        self.soc.configure_input(self.d3)

    def configure_dq_as_quad_output(self):
        self.soc.configure_output(self.d0, True)
        self.soc.configure_output(self.d1, True)
        self.soc.configure_output(self.d2, True)
        self.soc.configure_output(self.d3, True)

    def set_chip_select(self, value):
        self.soc.set_output(self.csn, value)

    def set_clock(self, value):
        self.soc.set_output(self.c, value)

    def set_hold(self, value):
        self.soc.set_output(self.d3, value)

    def set_write_protect(self, value):
        self.soc.set_output(self.d2, value)

    def set_reset(self, value):
        pass

    def set_dq_single(self, value: int):
        self.soc.set_output(self.d0, (value & 1) == 1)

    def get_dq_single(self) -> int:
        return 1 if self.soc.get_input(self.d1) else 0

    def set_dq_quad(self, value: int):
        self.soc.set_output(self.d0, True if (value & 0b0001) else False)
        self.soc.set_output(self.d1, True if (value & 0b0010) else False)
        self.soc.set_output(self.d2, True if (value & 0b0100) else False)
        self.soc.set_output(self.d3, True if (value & 0b1000) else False)

    def get_dq_quad(self) -> int:
        nibble = 0b0001 if self.soc.get_input(self.d0) else 0b0000
        nibble |= 0b0010 if self.soc.get_input(self.d0) else 0b0000
        nibble |= 0b0100 if self.soc.get_input(self.d0) else 0b0000
        nibble |= 0b1000 if self.soc.get_input(self.d0) else 0b0000
        return nibble

    def initialize(self):
        self.soc.configure_output(self.csn, True)
        self.soc.configure_output(self.c, False)
        self.configure_dq_as_single()

    def io(self, tx, rxn=0, skip=None):
        if skip is None:
            skip = len(tx)

        transactions = []
        self.soc.append_configure_output_transactions(transactions, self.d0, True)
        if self.d1 is not None:
            self.soc.append_configure_input_transactions(transactions, self.d1)
        if self.d2 is not None:
            self.soc.append_configure_output_transactions(transactions, self.d2, True)
        if self.d3 is not None:
            self.soc.append_configure_output_transactions(transactions, self.d3, True)
        self.soc.append_set_output_transactions(transactions, self.csn, False)
        count = max(len(tx), skip + rxn)
        gets = []
        for i in range(count):
            tx_byte = tx[i] if i < len(tx) else 0xff
            for j in range(8):
                self.soc.append_set_output_transactions(transactions, self.d0, (tx_byte & 0x80) != 0)
                tx_byte <<= 1
                self.soc.append_set_output_transactions(transactions, self.c, True)
                if self.d1 is not None:
                    gets.append(self.soc.append_get_input_transactions(transactions, self.d1))
                self.soc.append_set_output_transactions(transactions, self.c, False)
        self.soc.append_set_output_transactions(transactions, self.csn, True)
        self.soc.serial_wire_instrument.transfer(transactions)

        if self.d1 is None:
            return None

        rx = []
        for i in range(count):
            rx_byte = 0
            for j in range(8):
                get = gets[i * 8 + j]
                value = get()
                rx_byte <<= 1
                rx_byte |= 1 if value else 0
            if i >= skip:
                rx.append(rx_byte)
        return rx

    def read_id(self):
        tx = [0x9F]
        rx = self.io(tx, 4)
        return rx

    '''
    to enable the quad mode
    1. send ENTER QUAD INPUT/OUTPUT MODE command 0x35h
    2. send write enable cmd 0x06
    3. to write into enhanced volatile configuration register - send  0x61 command.
    4. 0x7F is written in the above register to activate in quad mode
    5. poll the configuration register i.e read the enhanced volatile config register command is 0x65 and wait untill it
    becomes 0X7F
    '''
    def enter_quad_mode(self):
        self.io([0x35], 0)
        self.configure_dq_as_quad_input()

    def io_quad(self, tx, rxn):
        self.set_chip_select(False)
        self.configure_dq_as_quad_output()
        for i in range(len(tx)):
            byte = tx[i]
            self.set_dq_quad(byte >> 4)
            self.set_clock(True)
            self.set_clock(False)
            self.set_dq_quad(byte & 0xf)
            self.set_clock(True)
            self.set_clock(False)
        self.configure_dq_as_quad_input()
        """
        for _ in range(2):
            self.set_clock(True)
            self.set_clock(False)
        """
        rx = []
        for i in range(rxn):
            nibble_h = self.get_dq_quad()
            self.set_clock(True)
            self.set_clock(False)
            nibble_l = self.get_dq_quad()
            self.set_clock(True)
            self.set_clock(False)
            byte = (nibble_h << 4) | nibble_l
            rx.append(byte)
        self.set_chip_select(True)
        return rx

    def read_id_quad(self):
        tx = [0xAF]
        rx = self.io_quad(tx, 4)
        return rx


class ProgramScript(FixtureScript):

    def __init__(self, presenter, fixture, mcu, name, serial_wire_instrument_number=0, access_port_id=0):
        super().__init__(presenter, fixture)
        self.mcu = mcu
        self.name = name
        self.serial_wire_instrument_number = serial_wire_instrument_number
        self.access_port_id = access_port_id

    def setup(self):
        super().setup()

    def main(self):
        super().main()

        serial_wire_instrument = self.fixture.serial_wire_instruments[self.serial_wire_instrument_number]
        flasher = Flasher(self.presenter, serial_wire_instrument, self.mcu, self.name)
        flasher.setup()
        self.log(str(flasher.rpc.firmware))
        flasher.program()

        self.status = Script.status_pass
