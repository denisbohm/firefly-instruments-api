import time
from .instruments import InstrumentManager
from .storage import FileSystem
from elftools.elf.elffile import ELFFile


class Fixture:

    def __init__(self, presenter):
        self.presenter = presenter
        self.manager = None
        self.indicator_instrument = None
        self.storage_instrument = None
        self.file_system = None

    def setup(self):
        self.manager = InstrumentManager()
        self.manager.open()
        self.manager.discover_instruments()

        self.indicator_instrument = self.manager.get_instrument(4)
        self.indicator_instrument.set(1.0, 0.0, 0.0)

        self.storage_instrument = self.manager.get_instrument(16)
        self.file_system = FileSystem(self.storage_instrument)
        self.presenter.log('Inspecting file system...')
        self.file_system.inspect()


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


class Firmware:

    def __init__(self):
        self.address = None
        self.data = None
        self.heap = None
        self.stack = None
        self.functions = None

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
        return address, size

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

class SerialWireDebugScript(FixtureScript):

    def __init__(self, presenter, fixture):
        super().__init__(presenter, fixture)
        self.functions = {}

    def setup(self):
        super().setup()

    def main(self):
        super().main()

        firmware = Firmware()
        firmware.load_elf("/Users/denis/sandbox/denisbohm/firefly-ice-firmware/FireflyFlashSTM32F4 THUMB Debug/FireflyFlashSTM32F4.elf")
        self.log(f"code: 0x{firmware.address:08x} size: 0x{len(firmware.data):08x}")
        self.log(f"stack: 0x{firmware.stack[0]:08x} size: 0x{firmware.stack[1]:08x}")
        self.log(f"heap: 0x{firmware.heap[0]:08x} size: 0x{firmware.heap[1]:08x}")
        for key, value in firmware.functions.items():
            self.log(f"{key} @ 0x{value:08x}")

        self.status = Script.status_pass

    def run(self, function, r0=0, r1=0, r2=0, r3=0, timeout=1.0):
        pass
