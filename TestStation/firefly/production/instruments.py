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


class StorageInstrument(Instrument):

    apiTypeReset = 0
    apiTypeErase = 1
    apiTypeWrite = 2
    apiTypeRead = 3
    apiTypeHash = 4

    maxTransferLength = 4096

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
            length = min(data.count - offset, StorageInstrument.maxTransferLength)
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

    def hash(self, address, length):
        arguments = FDBinary()
        arguments.put_varuint(address)
        arguments.put_varuint(length)
        results = self.call(StorageInstrument.apiTypeHash, arguments)
        result = results.get_bytes(20)
        return result


class SerialWireDebugTransfer:

    typeReadRegister = 0
    typeWriteRegister = 1
    typeReadMemory = 2
    typeWriteMemory = 3

    def __init__(self):
        self.type = None
        self.register_id = None
        self.address = None
        self.data = None

    @staticmethod
    def write_register(register_id, data):
        transfer = SerialWireDebugTransfer()
        transfer.type = SerialWireDebugTransfer.typeWriteRegister
        transfer.register_id = register_id
        transfer.data = data
        return transfer

    @staticmethod
    def read_register(register_id):
        transfer = SerialWireDebugTransfer()
        transfer.type = SerialWireDebugTransfer.typeReadRegister
        transfer.register_id = register_id
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

    def write_memory(self, address, data):
        arguments = FDBinary()
        arguments.put_varuint(address)
        arguments.put_varuint(data.count)
        arguments.put_bytes(data)
        results = self.call(SerialWireInstrument.apiTypeWriteMemory, arguments)
        code = results.get_varuint()
        if code != 0:
            raise IOError(f"memory transfer issue: code={code}")

    def read_memory(self, address, length):
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

    def transfer(self, transfers):
        response_count = 0
        arguments = FDBinary()
        arguments.put_varuint(transfers.count)
        for transfer in transfers:
            arguments.put_varuint(transfer.type)
            if transfer.type == SerialWireDebugTransfer.typeReadRegister:
                response_count += 1
                arguments.put_varuint(transfer.register_id)
            elif transfer.type == SerialWireDebugTransfer.typeWriteRegister:
                arguments.put_varuint(transfer.register_id)
                arguments.put_uint32(transfer.value)
            elif transfer.type == SerialWireDebugTransfer.typeReadMemory:
                response_count += 1
                arguments.put_uint32(transfer.address)
                arguments.put_varuint(transfer.length)
            elif transfer.type == SerialWireDebugTransfer.typeWriteMemory:
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
            if transfer.type == SerialWireDebugTransfer.typeReadRegister:
                transfer_type = results.get_varuint()
                if transfer_type != transfer.type:
                    raise IOError('transfer mismatch')
                register_id = results.get_varuint()
                if register_id != transfer.register_id:
                    raise IOError('transfer mismatch')
                transfer.value = results.get_uint32()
            elif transfer.type == SerialWireDebugTransfer.typeWriteRegister:
                break
            elif transfer.type == SerialWireDebugTransfer.typeReadMemory:
                transfer_type = results.get_varuint()
                if transfer_type != transfer.type:
                    raise IOError('transfer mismatch')
                address = results.get_uint32()
                if address != transfer.address:
                    raise IOError('transfer mismatch')
                length = results.get_varuint()
                if length != transfer.length:
                    raise IOError('transfer mismatch')
                transfer.data = results.get_bytes(length)
            elif transfer.type == SerialWireDebugTransfer.typeWriteMemory:
                break
            else:
                break

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
        if code != 0:
            raise IOError(f"memory transfer issue: code={code}")

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
            'SerialWireDebug': SerialWireInstrument
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
            remaining -= sublength

    def read(self):
        detour = Detour()
        while detour.state != Detour.state_success:
            data = self.device.Read()
            print(data)
            detour.event(data)
        binary = FDBinary(detour.buffer)
        identifier = binary.get_varuint()
        api = binary.get_varuint()
        count = binary.get_varuint()
        content = binary.get_bytes(count)
        print(f"done identifier={identifier}, api={api}, count={count}, content={content}")
        return identifier, type, content

    def call(self, identifier, api, content=None):
        self.write(identifier, api, content)
        return_identifier, return_type, return_content = self.read()
        assert identifier == return_identifier
        assert type == return_type
        return return_content

    def discover_instruments(self):
        results = FDBinary(self.call(self.identifier, InstrumentManager.apiTypeDiscoverInstruments))
        count = results.get_varuint()
        for _ in range(count):
            category = results.get_string()
            identifier = results.get_varuint()
            print(f"category={category}, identifier={identifier}")
            if category not in self.instrumentClassByCategory:
                continue
            instrument_class = self.instrumentClassByCategory[category]
            instrument = instrument_class(self, identifier)
            self.instrumentsByIdentifier[identifier] = instrument

    def get_instrument(self, identifier):
        return self.instrumentsByIdentifier[identifier]
