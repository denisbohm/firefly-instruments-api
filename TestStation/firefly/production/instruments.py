from enum import Enum
from typing import Set
from typing import Tuple
from .usb import MacOsHidDevice
from .binary import FDBinary


class Instrument:

    def __init__(self, manager, identifier):
        self.manager = manager
        self.identifier = identifier

    def invoke(self, api, arguments=None):
        self.manager.write(self.identifier, api, arguments.data if arguments is not None else None)
        
    def call(self, api, arguments=None):
        return FDBinary(self.manager.call(self.identifier, api, arguments.data if arguments is not None else None))


class RelayInstrument(Instrument):

    apiTypeReset = 0
    apiTypeSetState = 1

    def __init__(self, manager, identifier):
        super().__init__(manager, identifier)

    def reset(self):
        self.invoke(RelayInstrument.apiTypeReset)

    def set(self, value):
        arguments = FDBinary()
        arguments.put_uint8(1 if value else 0)
        self.invoke(RelayInstrument.apiTypeSetState, arguments)


class IndicatorInstrument(Instrument):

    apiTypeReset = 0
    apiTypeSetRGB = 1

    def __init__(self, manager, identifier):
        super().__init__(manager, identifier)

    def reset(self):
        self.invoke(IndicatorInstrument.apiTypeReset)

    def set(self, red, green, blue):
        arguments = FDBinary()
        arguments.put_float32(red)
        arguments.put_float32(green)
        arguments.put_float32(blue)
        self.invoke(IndicatorInstrument.apiTypeSetRGB, arguments)


class CurrentInstrument(Instrument):

    apiTypeReset = 0
    apiTypeConvertCurrent = 1

    def __init__(self, manager, identifier):
        super().__init__(manager, identifier)

    def reset(self):
        self.invoke(CurrentInstrument.apiTypeReset)

    def convert(self):
        results = self.call(CurrentInstrument.apiTypeConvertCurrent)
        current = results.get_float32()
        return current


class BatteryInstrument(Instrument):

    apiTypeReset = 0
    apiTypeConvertCurrent = 1
    apiTypeSetVoltage = 2
    apiTypeSetEnabled = 3
    apiTypeConvertCurrentContinuous = 4
    apiTypeConvertCurrentContinuousComplete = 5

    def __init__(self, manager, identifier):
        super().__init__(manager, identifier)

    def reset(self):
        self.invoke(BatteryInstrument.apiTypeReset)

    def convert(self):
        results = self.call(BatteryInstrument.apiTypeConvertCurrent)
        current = results.get_float32()
        return current

    def set_enabled(self, value):
        arguments = FDBinary()
        arguments.put_uint8(1 if value else 0)
        self.invoke(BatteryInstrument.apiTypeSetEnabled, arguments)

    def set_voltage(self, value):
        arguments = FDBinary()
        arguments.put_float32(value)
        self.invoke(BatteryInstrument.apiTypeSetVoltage, arguments)


class VoltageInstrument(Instrument):

    apiTypeReset = 0
    apiTypeConvertVoltage = 1

    def __init__(self, manager, identifier):
        super().__init__(manager, identifier)

    def reset(self):
        self.invoke(VoltageInstrument.apiTypeReset)

    def convert(self):
        results = self.call(VoltageInstrument.apiTypeConvertVoltage)
        voltage = results.get_float32()
        return voltage


class GpioInstrument(Instrument):

    apiTypeReset = 0
    apiTypeGetCapabilities = 1
    apiTypeGetConfiguration = 2
    apiTypeSetConfiguration = 3
    apiTypeGetDigitalInput = 4
    apiTypeSetDigitalOutput = 5
    apiTypeGetAnalogInput = 6
    apiTypeSetAnalogOutput = 7
    apiTypeGetAuxiliaryConfiguration = 8
    apiTypeSetAuxiliaryConfiguration = 9
    apiTypeGetAuxiliaryInput = 10
    apiTypeSetAuxiliaryOutput = 11

    class Capability(Enum):
        analog_input: int = 0
        analog_output: int = 1
        auxiliary: int = 2

    class Domain(Enum):
        digital: int = 0
        analog: int = 1

    class Direction(Enum):
        input: int = 0
        output: int = 1

    class Drive(Enum):
        push_pull: int = 0
        open_drain: int = 1

    class Pull(Enum):
        none: int = 0
        up: int = 1
        down: int = 2

    def __init__(self, manager, identifier):
        super().__init__(manager, identifier)

    def reset(self):
        self.invoke(GpioInstrument.apiTypeReset)

    def get_capabilities(self) -> Set[Capability]:
        results = self.call(GpioInstrument.apiTypeGetCapabilities)
        capabilities = set()
        capability_bits = results.get_uint32()
        if capability_bits & 0x00000001:
            capabilities.add(GpioInstrument.Capability.analog_input)
        if capability_bits & 0x00000002:
            capabilities.add(GpioInstrument.Capability.analog_output)
        if capability_bits & 0x00000004:
            capabilities.add(GpioInstrument.Capability.auxiliary)
        return capabilities

    def get_configuration(self) -> Tuple[Domain, Direction, Drive, Pull]:
        results = self.call(GpioInstrument.apiTypeGetConfiguration)
        domain = self.Domain(results.get_uint8())
        direction = self.Direction(results.get_uint8())
        drive = self.Drive(results.get_uint8())
        pull = self.Pull(results.get_uint8())
        return domain, direction, drive, pull

    def set_configuration(
        self, domain=Domain.digital, direction=Direction.input, drive=Drive.push_pull, pull=Pull.none
    ):
        arguments = FDBinary()
        arguments.put_uint8(domain.value)
        arguments.put_uint8(direction.value)
        arguments.put_uint8(drive.value)
        arguments.put_uint8(pull.value)
        self.invoke(GpioInstrument.apiTypeSetConfiguration, arguments)

    def get_digital_input(self) -> bool:
        results = self.call(GpioInstrument.apiTypeGetDigitalInput)
        bit = results.get_uint8() != 0
        return bit

    def set_digital_output(self, value: bool):
        arguments = FDBinary()
        arguments.put_uint8(1 if value else 0)
        self.invoke(GpioInstrument.apiTypeSetDigitalOutput, arguments)

    def get_analog_input(self) -> float:
        results = self.call(GpioInstrument.apiTypeGetAnalogInput)
        value = results.get_float32()
        return value

    def set_analog_output(self, value: float):
        arguments = FDBinary()
        arguments.put_float32(value)
        self.invoke(GpioInstrument.apiTypeSetAnalogOutput, arguments)

    def get_auxiliary_configuration(self) -> Tuple[Domain, Direction, Drive, Pull]:
        results = self.call(GpioInstrument.apiTypeGetAuxiliaryConfiguration)
        domain = self.Domain(results.get_uint8())
        direction = self.Direction(results.get_uint8())
        drive = self.Drive(results.get_uint8())
        pull = self.Pull(results.get_uint8())
        return domain, direction, drive, pull

    def set_auxiliary_configuration(
        self, domain=Domain.digital, direction=Direction.input, drive=Drive.push_pull, pull=Pull.none
    ):
        arguments = FDBinary()
        arguments.put_uint8(domain.value)
        arguments.put_uint8(direction.value)
        arguments.put_uint8(drive.value)
        arguments.put_uint8(pull.value)
        self.invoke(GpioInstrument.apiTypeSetAuxiliaryConfiguration, arguments)

    def get_auxiliary_input(self) -> bool:
        results = self.call(GpioInstrument.apiTypeGetAuxiliaryInput)
        bit = results.get_uint8() != 0
        return bit

    def set_auxiliary_output(self, value: bool):
        arguments = FDBinary()
        arguments.put_uint8(1 if value else 0)
        self.invoke(GpioInstrument.apiTypeSetAuxiliaryOutput, arguments)


class StorageInstrument(Instrument):

    apiTypeReset = 0
    apiTypeErase = 1
    apiTypeWrite = 2
    apiTypeRead = 3
    apiTypeHash = 4
    apiTypeFileMkfs = 5
    apiTypeFileList = 6
    apiTypeFileOpen = 7
    apiTypeFileUnlink = 8
    apiTypeFileAddress = 9
    apiTypeFileExpand = 10
    apiTypeFileWrite = 11
    apiTypeFileRead = 12

    maxTransferLength = 4096

    FA_READ = 0x01
    FA_WRITE = 0x02
    FA_OPEN_EXISTING = 0x00
    FA_CREATE_NEW = 0x04
    FA_CREATE_ALWAYS = 0x08
    FA_OPEN_ALWAYS = 0x10
    FA_OPEN_APPEND = 0x30

    class Info:

        def __init__(self, name, size, date, time):
            self.name = name
            self.size = size
            self.date = date
            self.time = time

    def __init__(self, manager, identifier):
        super().__init__(manager, identifier)

    def reset(self):
        self.invoke(StorageInstrument.apiTypeReset)

    def erase(self, address, length):
        arguments = FDBinary()
        arguments.put_varuint(address)
        arguments.put_varuint(length)
        self.invoke(StorageInstrument.apiTypeErase, arguments)

    def write(self, address, data):
        offset = 0
        while offset < len(data):
            length = min(len(data) - offset, StorageInstrument.maxTransferLength)
            arguments = FDBinary()
            arguments.put_varuint(address + offset)
            arguments.put_varuint(length)
            arguments.put_bytes(data[offset:offset + length])
            self.invoke(StorageInstrument.apiTypeWrite, arguments)
            self.manager.echo([0xbe, 0xef])
            offset += length

    def read(self, address, length, sublength=0, substride=0):
        if sublength == 0:
            sublength = length

        # !!! this won't work for sublengths larger than the maxTransferLength -denis
        data = [0] * length
        offset = 0
        while offset < length:
            transfer_address = address + offset
            transfer_length = min(len(data) - offset, StorageInstrument.maxTransferLength)
            transfer_sublength = min(sublength, transfer_length)
            arguments = FDBinary()
            arguments.put_varuint(transfer_address)
            arguments.put_varuint(transfer_length)
            arguments.put_varuint(transfer_sublength)
            arguments.put_varuint(substride)
            results = self.call(StorageInstrument.apiTypeRead, arguments)
            subdata = results.get_bytes(transfer_length)
            data[offset:offset + transfer_length] = subdata
            offset += transfer_length
        return data

    def read_lots(self, address, length):
        data = []
        remaining = length
        subaddress = address
        while True:
            count = min(remaining, StorageInstrument.maxTransferLength)
            if count == 0:
                break
            subdata = self.read(subaddress, count)
            data.extend(subdata)
            subaddress += count
            remaining -= count
        return data

    def hash(self, address, length):
        arguments = FDBinary()
        arguments.put_varuint(address)
        arguments.put_varuint(length)
        results = self.call(StorageInstrument.apiTypeHash, arguments)
        result = results.get_bytes(20)
        return result

    def file_mkfs(self):
        results = self.call(StorageInstrument.apiTypeFileMkfs)
        result = results.get_uint8() != 0
        return result

    def file_list(self):
        results = self.call(StorageInstrument.apiTypeFileList)
        count = results.get_varuint()
        list = []
        for _ in range(count):
            name = results.get_string()
            size = results.get_uint32()
            date = results.get_uint32()
            time = results.get_uint32()
            list.append(StorageInstrument.Info(name, size, date, time))
        return list

    def file_open(self, name, mode):
        arguments = FDBinary()
        arguments.put_string(name)
        arguments.put_varuint(mode)
        results = self.call(StorageInstrument.apiTypeFileOpen, arguments)
        result = results.get_uint8() != 0
        return result

    def file_unlink(self, name):
        arguments = FDBinary()
        arguments.put_string(name)
        results = self.call(StorageInstrument.apiTypeFileUnlink, arguments)
        result = results.get_uint8() != 0
        return result

    def file_address(self, name):
        arguments = FDBinary()
        arguments.put_string(name)
        results = self.call(StorageInstrument.apiTypeFileAddress, arguments)
        result = results.get_uint8() != 0
        address = results.get_uint32()
        return address

    def file_expand(self, name, size):
        arguments = FDBinary()
        arguments.put_string(name)
        arguments.put_uint32(size)
        results = self.call(StorageInstrument.apiTypeFileExpand, arguments)
        result = results.get_uint8() != 0
        return result

    def file_write_raw(self, name, offset, data):
        arguments = FDBinary()
        arguments.put_string(name)
        arguments.put_uint32(offset)
        arguments.put_uint32(len(data))
        arguments.put_bytes(data)
        results = self.call(StorageInstrument.apiTypeFileWrite, arguments)
        result = results.get_uint8() != 0
        return result

    def file_write(self, name, offset, data):
        remaining = len(data)
        suboffset = offset
        while True:
            count = min(remaining, StorageInstrument.maxTransferLength)
            if count == 0:
                break
            subdata = data[suboffset:suboffset + count]
            self.file_write_raw(name, suboffset, subdata)
            suboffset += count
            remaining -= count

    def file_read_raw(self, name, offset, size):
        arguments = FDBinary()
        arguments.put_string(name)
        arguments.put_uint32(offset)
        arguments.put_uint32(size)
        results = self.call(StorageInstrument.apiTypeFileRead, arguments)
        result = results.get_uint8() != 0
        if result:
            actual_size = results.get_uint32()
            data = results.get_bytes(actual_size)
        else:
            data = []
        return data

    def file_read(self, name, offset, size):
        data = []
        remaining = size
        suboffset = offset
        while True:
            count = min(remaining, StorageInstrument.maxTransferLength)
            if count == 0:
                break
            subdata = self.file_read_raw(name, suboffset, count)
            data.extend(subdata)
            suboffset += count
            remaining -= count
        return data


class SerialWireDebugTransfer:

    typeReadRegister = 0
    typeWriteRegister = 1
    typeReadMemory = 2
    typeWriteMemory = 3
    typeReadPort = 4
    typeWritePort = 5
    typeSelectAndReadAccessPort = 6
    typeSelectAndWriteAccessPort = 7
    typeReadData = 8
    typeWriteData = 9

    portDebug = 0
    portAccess = 1

    def __init__(self):
        self.type = None
        self.port = None
        self.register = None
        self.address = None
        self.length = None
        self.data = None

    @staticmethod
    def write_port(port, register, data):
        transfer = SerialWireDebugTransfer()
        transfer.type = SerialWireDebugTransfer.typeWritePort
        transfer.port = port
        transfer.register = register
        transfer.data = data
        return transfer

    @staticmethod
    def read_port(port, register):
        transfer = SerialWireDebugTransfer()
        transfer.type = SerialWireDebugTransfer.typeReadPort
        transfer.port = port
        transfer.register = register
        return transfer

    @staticmethod
    def select_and_write_access_port(register, data):
        transfer = SerialWireDebugTransfer()
        transfer.type = SerialWireDebugTransfer.typeSelectAndWriteAccessPort
        transfer.register = register
        transfer.data = data
        return transfer

    @staticmethod
    def select_and_read_access_port(register):
        transfer = SerialWireDebugTransfer()
        transfer.type = SerialWireDebugTransfer.typeSelectAndReadAccessPort
        transfer.register = register
        return transfer

    @staticmethod
    def write_register(register, data):
        transfer = SerialWireDebugTransfer()
        transfer.type = SerialWireDebugTransfer.typeWriteRegister
        transfer.register = register
        transfer.data = data
        return transfer

    @staticmethod
    def read_register(register):
        transfer = SerialWireDebugTransfer()
        transfer.type = SerialWireDebugTransfer.typeReadRegister
        transfer.register = register
        return transfer

    @staticmethod
    def write_memory(address, data):
        transfer = SerialWireDebugTransfer()
        transfer.type = SerialWireDebugTransfer.typeWriteMemory
        transfer.address = address
        transfer.data = data
        return transfer

    @staticmethod
    def read_memory(address):
        transfer = SerialWireDebugTransfer()
        transfer.type = SerialWireDebugTransfer.typeReadMemory
        transfer.address = address
        return transfer

    @staticmethod
    def write_data(address, data):
        transfer = SerialWireDebugTransfer()
        transfer.type = SerialWireDebugTransfer.typeWriteData
        transfer.address = address
        transfer.data = data
        return transfer

    @staticmethod
    def read_data(address, length):
        transfer = SerialWireDebugTransfer()
        transfer.type = SerialWireDebugTransfer.typeReadData
        transfer.address = address
        transfer.length = length
        return transfer


class SerialWireInstrument(Instrument):

    apiTypeReset = 0
    apiTypeSetOutputs = 1
    apiTypeGetInputs = 2
    apiTypeShiftOutBits = 3
    apiTypeShiftOutData = 4
    apiTypeShiftInBits = 5
    apiTypeShiftInData = 6
    apiTypeFlush = 7
    apiTypeData = 8
    apiTypeSetEnabled = 9
    apiTypeWriteMemory = 10
    apiTypeReadMemory = 11
    apiTypeWriteFromStorage = 12
    apiTypeCompareToStorage = 13
    apiTypeTransfer = 14
    apiTypeSetHalfBitDelay = 15
    apiTypeSetTargetId = 16
    apiTypeSetAccessPortId = 17
    apiTypeConnect = 18

    outputIndicator = 0
    outputReset = 1
    outputDirection = 2

    def __init__(self, manager, identifier):
        super().__init__(manager, identifier)

    def reset(self):
        self.invoke(SerialWireInstrument.apiTypeReset)

    def set_enabled(self, value):
        arguments = FDBinary()
        arguments.put_uint8(1 if value else 0)
        self.invoke(SerialWireInstrument.apiTypeSetEnabled, arguments)

    def set_half_bit_delay(self, value):
        arguments = FDBinary()
        arguments.put_uint32(value)
        self.invoke(SerialWireInstrument.apiTypeSetHalfBitDelay, arguments)

    def set(self, gpio, value):
        bits = 1 << gpio
        values = bits if value else 0
        arguments = FDBinary()
        arguments.put_uint8(bits)
        arguments.put_uint8(values)
        self.invoke(SerialWireInstrument.apiTypeSetOutputs, arguments)

    def get(self, gpio):
        bits = 1 << gpio
        arguments = FDBinary()
        arguments.put_uint8(bits)
        results = self.call(SerialWireInstrument.apiTypeGetInputs, arguments)
        value = results.get_varuint()
        return value != 0

    def get_reset(self):
        return self.get(0)

    def set_indicator(self, value):
        self.set(SerialWireInstrument.outputIndicator, value)

    def set_reset(self, value):
        self.set(SerialWireInstrument.outputReset, value)

    def turn_to_read(self):
        self.set(SerialWireInstrument.outputDirection, False)

    def turn_to_write(self):
        self.set(SerialWireInstrument.outputDirection, True)

    def shift_out_bits(self, byte, bit_count):
        assert bit_count > 0
        arguments = FDBinary()
        arguments.put_uint8(bit_count - 1)
        arguments.put_uint8(byte)
        self.invoke(SerialWireInstrument.apiTypeShiftOutBits, arguments)

    def shift_out_data(self, data):
        assert data.count > 0
        arguments = FDBinary()
        arguments.put_varuint(data.count - 1)
        arguments.put_bytes(data)
        self.invoke(SerialWireInstrument.apiTypeShiftOutData, arguments)

    def shift_in_bits(self, bit_count):
        arguments = FDBinary()
        arguments.put_uint8(bit_count - 1)
        self.invoke(SerialWireInstrument.apiTypeShiftInBits, arguments)

    def shift_in_data(self, byte_count):
        arguments = FDBinary()
        arguments.put_varuint(byte_count - 1)
        self.invoke(SerialWireInstrument.apiTypeShiftInData, arguments)

    def write_memory_raw(self, address, data):
        arguments = FDBinary()
        arguments.put_varuint(address)
        arguments.put_varuint(len(data))
        arguments.put_bytes(data)
        results = self.call(SerialWireInstrument.apiTypeWriteMemory, arguments)
        code = results.get_varuint()
        if code != 0:
            raise IOError(f"memory transfer issue: code={code}")

    def write_memory(self, address, data):
        max_count = 1024
        subaddress = address
        while True:
            offset = subaddress - address
            count = min(len(data) - offset, max_count)
            if count == 0:
                break
            subdata = data[offset:offset + count]
            self.write_memory_raw(subaddress, subdata)
            subaddress += count

    def read_memory_raw(self, address, length):
        arguments = FDBinary()
        arguments.put_varuint(address)
        arguments.put_varuint(length)
        results = self.call(SerialWireInstrument.apiTypeReadMemory, arguments)
        code = results.get_varuint()
        if code != 0:
            raise IOError(f"memory transfer issue: code={code}")
        result = results.get_remaining_data()
        if len(result) != length:
            raise IOError(f"memory transfer issue: code={code}")
        return result

    def read_memory(self, address, length):
        max_count = 1024
        data = []
        subaddress = address
        while True:
            offset = subaddress - address
            count = min(length - offset, max_count)
            if count == 0:
                break
            subdata = self.read_memory_raw(subaddress, count)
            data.extend(subdata)
            subaddress += count
        return data

    def transfer(self, transfers):
        response_count = 0
        arguments = FDBinary()
        arguments.put_varuint(len(transfers))
        for transfer in transfers:
            arguments.put_varuint(transfer.type)
            if transfer.type == SerialWireDebugTransfer.typeReadPort:
                response_count += 1
                arguments.put_uint8(transfer.port)
                arguments.put_uint8(transfer.register)
            elif transfer.type == SerialWireDebugTransfer.typeWritePort:
                arguments.put_uint8(transfer.port)
                arguments.put_uint8(transfer.register)
                arguments.put_uint32(transfer.data)
            elif transfer.type == SerialWireDebugTransfer.typeSelectAndReadAccessPort:
                response_count += 1
                arguments.put_uint8(transfer.register)
            elif transfer.type == SerialWireDebugTransfer.typeSelectAndWriteAccessPort:
                arguments.put_uint8(transfer.register)
                arguments.put_uint32(transfer.data)
            elif transfer.type == SerialWireDebugTransfer.typeReadRegister:
                response_count += 1
                arguments.put_varuint(transfer.register)
            elif transfer.type == SerialWireDebugTransfer.typeWriteRegister:
                arguments.put_varuint(transfer.register)
                arguments.put_uint32(transfer.data)
            elif transfer.type == SerialWireDebugTransfer.typeReadMemory:
                response_count += 1
                arguments.put_uint32(transfer.address)
            elif transfer.type == SerialWireDebugTransfer.typeWriteMemory:
                arguments.put_uint32(transfer.address)
                arguments.put_uint32(transfer.data)
            elif transfer.type == SerialWireDebugTransfer.typeReadData:
                response_count += 1
                arguments.put_uint32(transfer.address)
                arguments.put_varuint(transfer.length)
            elif transfer.type == SerialWireDebugTransfer.typeWriteData:
                arguments.put_uint32(transfer.address)
                arguments.put_varuint(len(transfer.data))
                arguments.put_bytes(transfer.data)
            else:
                break
        results = self.call(SerialWireInstrument.apiTypeTransfer, arguments)
        code = results.get_varuint()
        if code != 0:
            raise IOError(f"memory transfer issue: code={code}")
        count = results.get_varuint()
        if count != response_count:
            raise IOError('transfer mismatch')
        for transfer in transfers:
            if transfer.type == SerialWireDebugTransfer.typeReadPort:
                transfer_type = results.get_varuint()
                if transfer_type != transfer.type:
                    raise IOError('transfer mismatch')
                port = results.get_uint8()
                if port != transfer.port:
                    raise IOError('transfer mismatch')
                register = results.get_uint8()
                if register != transfer.register:
                    raise IOError('transfer mismatch')
                transfer.data = results.get_uint32()
            elif transfer.type == SerialWireDebugTransfer.typeWritePort:
                break
            if transfer.type == SerialWireDebugTransfer.typeSelectAndReadAccessPort:
                transfer_type = results.get_varuint()
                if transfer_type != transfer.type:
                    raise IOError('transfer mismatch')
                register = results.get_uint8()
                if register != transfer.register:
                    raise IOError('transfer mismatch')
                transfer.data = results.get_uint32()
            elif transfer.type == SerialWireDebugTransfer.typeSelectAndWriteAccessPort:
                break
            if transfer.type == SerialWireDebugTransfer.typeReadRegister:
                transfer_type = results.get_varuint()
                if transfer_type != transfer.type:
                    raise IOError('transfer mismatch')
                register = results.get_varuint()
                if register != transfer.register:
                    raise IOError('transfer mismatch')
                transfer.data = results.get_uint32()
            elif transfer.type == SerialWireDebugTransfer.typeWriteRegister:
                break
            elif transfer.type == SerialWireDebugTransfer.typeReadMemory:
                transfer_type = results.get_varuint()
                if transfer_type != transfer.type:
                    raise IOError('transfer mismatch')
                address = results.get_uint32()
                if address != transfer.address:
                    raise IOError('transfer mismatch')
                transfer.data = results.get_uint32()
            elif transfer.type == SerialWireDebugTransfer.typeWriteMemory:
                break
            elif transfer.type == SerialWireDebugTransfer.typeReadData:
                transfer_type = results.get_varuint()
                if transfer_type != transfer.type:
                    raise IOError('transfer mismatch')
                address = results.get_uint32()
                if address != transfer.address:
                    raise IOError('transfer mismatch')
                transfer.data = results.get_uint32()
            elif transfer.type == SerialWireDebugTransfer.typeWriteData:
                break
            else:
                break

    def read_port(self, port, register):
        transfer = SerialWireDebugTransfer.read_port(port, register)
        self.transfer([transfer])
        return transfer.data

    def write_port(self, port, register, data):
        transfer = SerialWireDebugTransfer.write_port(port, register, data)
        self.transfer([transfer])

    def select_and_read_access_port(self, register):
        transfer = SerialWireDebugTransfer.select_and_read_access_port(register)
        self.transfer([transfer])
        return transfer.data

    def select_and_write_access_port(self, register, data):
        transfer = SerialWireDebugTransfer.select_and_write_access_port(register, data)
        self.transfer([transfer])

    def read_memory_uint32(self, address):
        transfer = SerialWireDebugTransfer.read_memory(address)
        self.transfer([transfer])
        return transfer.data

    def write_memory_uint32(self, address, data):
        transfer = SerialWireDebugTransfer.write_memory(address, data)
        self.transfer([transfer])

    def read_data(self, address, length):
        transfer = SerialWireDebugTransfer.read_data(address, length)
        self.transfer([transfer])
        return transfer.data

    def write_data(self, address, data):
        transfer = SerialWireDebugTransfer.write_memory(address, data)
        self.transfer([transfer])

    def read_register(self, register):
        transfer = SerialWireDebugTransfer.read_register(register)
        self.transfer([transfer])
        return transfer.data

    def write_register(self, register, data):
        transfer = SerialWireDebugTransfer.write_register(register, data)
        self.transfer([transfer])

    def write_from_storage(self, address, length, storage_identifier, storage_address):
        arguments = FDBinary()
        arguments.put_varuint(address)
        arguments.put_varuint(length)
        arguments.put_varuint(storage_identifier)
        arguments.put_varuint(storage_address)
        results = self.call(SerialWireInstrument.apiTypeWriteFromStorage, arguments)
        code = results.get_varuint()
        if code != 0:
            raise IOError(f"memory transfer issue: code={code}")

    def compare_to_storage(self, address, length, storage_identifier, storage_address):
        arguments = FDBinary()
        arguments.put_varuint(address)
        arguments.put_varuint(length)
        arguments.put_varuint(storage_identifier)
        arguments.put_varuint(storage_address)
        results = self.call(SerialWireInstrument.apiTypeCompareToStorage, arguments)
        code = results.get_varuint()
        return code

    def set_target_id(self, value):
        arguments = FDBinary()
        arguments.put_uint32(value)
        self.invoke(SerialWireInstrument.apiTypeSetTargetId, arguments)

    def set_access_port_id(self, value):
        arguments = FDBinary()
        arguments.put_uint32(value)
        self.invoke(SerialWireInstrument.apiTypeSetAccessPortId, arguments)

    def connect(self):
        results = self.call(SerialWireInstrument.apiTypeConnect)
        code = results.get_varuint()
        if code != 0:
            raise IOError(f"connect issue: code={code}")
        dpid = results.get_uint32()
        return dpid


class Detour:

    state_clear = 0
    state_intermediate = 1
    state_success = 2

    def __init__(self):
        self.state = Detour.state_clear
        self.buffer = []
        self.length = 0
        self.sequenceNumber = 0

    def clear(self):
        self.state = Detour.state_clear
        self.length = 0
        self.sequenceNumber = 0
        self.buffer = []

    def event(self, data):
        binary = FDBinary(data)
        event_sequence_number = binary.get_varuint()
        if event_sequence_number == 0:
            if self.sequenceNumber != 0:
                raise IOError('unexpected start')
            self.start(binary.get_remaining_data())
        else:
            if event_sequence_number != self.sequenceNumber:
                raise IOError('out of sequence')
            self.extend(binary.get_remaining_data())

    def start(self, data):
        binary = FDBinary(data)
        self.state = Detour.state_intermediate
        self.length = binary.get_varuint()
        self.sequenceNumber = 0
        self.buffer = []
        self.extend(binary.get_remaining_data())

    def extend(self, data):
        total = len(self.buffer) + len(data)
        if total <= self.length:
            self.buffer.extend(data)
        else:
            # silently ignore any extra data at the end of the transfer (due to fixed size transport) -denis
            self.buffer.extend(data[0:self.length - len(self.buffer)])
        if len(self.buffer) >= self.length:
            self.state = Detour.state_success
        else:
            self.sequenceNumber += 1


class InstrumentManager:

    apiTypeResetInstruments = 0
    apiTypeDiscoverInstruments = 1
    apiTypeEcho = 2

    def __init__(self):
        self.device = None
        self.identifier = 0
        self.instrumentsByIdentifier = {}
        self.instrumentClassByCategory = {
            'Indicator': IndicatorInstrument,
            'Relay': RelayInstrument,
            'Voltage': VoltageInstrument,
            'Current': CurrentInstrument,
            'Battery': BatteryInstrument,
            'Storage': StorageInstrument,
            'SerialWire': SerialWireInstrument,
            'Gpio': GpioInstrument
        }

    def open(self):
        self.device = MacOsHidDevice.open(0x0483, 0x5710)

    def write(self, identifier, api, content=None):
        if content is None:
            content = []
        packet = FDBinary()
        packet.put_varuint(identifier)
        packet.put_varuint(api)
        packet.put_varuint(len(content))
        packet.put_bytes(content)
        binary = FDBinary()
        binary.put_varuint(len(packet.data))
        binary.put_bytes(packet.data)
        data = binary.data
        sequence_number = 0
        offset = 0
        remaining = len(data)
        while remaining > 0:
            sublength = 63 if remaining >= 63 else remaining
            subdata = [sequence_number] + data[offset:offset + sublength] + [0] * (63 - sublength)
            self.device.Write(subdata, report_id=0x81)
            sequence_number += 1
            offset += sublength
            remaining -= sublength

    def read(self):
        detour = Detour()
        while detour.state != Detour.state_success:
            data = self.device.Read()
            detour.event(data)
        binary = FDBinary(detour.buffer)
        identifier = binary.get_varuint()
        api = binary.get_varuint()
        count = binary.get_varuint()
        content = binary.get_bytes(count)
        return identifier, type, content

    def call(self, identifier, api, content=None):
        self.write(identifier, api, content)
        return_identifier, return_type, return_content = self.read()
        assert identifier == return_identifier
        assert type == return_type
        return return_content

    def echo(self, data):
        return self.call(self.identifier, InstrumentManager.apiTypeEcho, data)

    def discover_instruments(self):
        results = FDBinary(self.call(self.identifier, InstrumentManager.apiTypeDiscoverInstruments))
        count = results.get_varuint()
        for _ in range(count):
            category = results.get_string()
            identifier = results.get_varuint()
#            print(f"category={category}, identifier={identifier}")
            if category not in self.instrumentClassByCategory:
                continue
            instrument_class = self.instrumentClassByCategory[category]
            instrument = instrument_class(self, identifier)
            self.instrumentsByIdentifier[identifier] = instrument

    def get_instrument(self, identifier):
        if identifier not in self.instrumentsByIdentifier:
            raise IOError(f'instrument {identifier} not found')
        return self.instrumentsByIdentifier[identifier]
