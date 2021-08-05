import struct


class FDBinary:

    FLAG_OVERFLOW = 0x00000001
    FLAG_INVALID_REPRESENTATION = 0x00000002
    FLAG_OUT_OF_BOUNDS = 0x00000004

    def __init__(self, data=None, limit=None):
        if not data:
            data = []
        self.data = data
        self.limit = limit
        self.get_index = 0
        self.flags = 0

    def reset(self):
        self.get_index = 0
        self.flags = 0

    def remove(self, index, length):
        self.data = self.data[0:index] + self.data[index + length:]
        if self.get_index > (index + length):
            self.get_index -= length
        elif self.get_index > index:
            self.get_index = index

    def remaining_length(self):
        return len(self.data) - self.get_index

    def get_remaining_data(self):
        return self.get_bytes(self.remaining_length())

    def get_check(self, length):
        if (self.get_index + length) <= len(self.data):
            return True
        self.flags |= FDBinary.FLAG_OVERFLOW
        return False

    def get_bytes(self, length):
        if not self.get_check(length):
            return []
        result = self.data[self.get_index:self.get_index + length]
        self.get_index += length
        return result

    def get_uint8(self):
        if not self.get_check(1):
            return 0
        result = self.data[self.get_index]
        self.get_index += 1
        return result

    def get_uint16(self):
        if not self.get_check(2):
            return 0
        b0 = self.data[self.get_index]
        b1 = self.data[self.get_index + 1]
        result = (b1 << 8) | b0
        self.get_index += 2
        return result

    def get_uint24(self):
        if not self.get_check(3):
            return 0
        b0 = self.data[self.get_index]
        b1 = self.data[self.get_index + 1]
        b2 = self.data[self.get_index + 2]
        result = (b2 << 16) | (b1 << 8) | b0
        self.get_index += 3
        return result

    def get_uint32(self):
        if not self.get_check(4):
            return 0
        b0 = self.data[self.get_index]
        b1 = self.data[self.get_index + 1]
        b2 = self.data[self.get_index + 2]
        b3 = self.data[self.get_index + 3]
        result = (b3 << 24) | (b2 << 16) | (b1 << 8) | b0
        self.get_index += 4
        return result

    def get_uint64(self):
        if not self.get_check(8):
            return 0
        buffer = bytes(self.data[self.get_index:self.get_index + 8])
        result = struct.unpack('<Q', buffer)
        self.get_index += 8
        return result

    def get_float16(self):
        if not self.get_check(2):
            return 0
        buffer = bytes(self.data[self.get_index:self.get_index + 2])
        result = struct.unpack('<e', buffer)
        self.get_index += 2
        return result

    def get_float32(self):
        if not self.get_check(4):
            return 0
        buffer = bytes(self.data[self.get_index:self.get_index + 4])
        result = struct.unpack('<f', buffer)
        self.get_index += 4
        return result

    def get_float64(self):
        if not self.get_check(8):
            return 0
        buffer = bytes(self.data[self.get_index:self.get_index + 8])
        result = struct.unpack('<d', buffer)
        self.get_index += 8
        return result

    def get_varuint(self):
        value = 0
        remaining = len(self.data) - self.get_index
        index = 0
        while index < remaining:
            byte = self.data[self.get_index]
            self.get_index += 1
            value |= (byte & 0x7f) << (index * 7)
            if (byte & 0x80) == 0:
                return value
            if (value & 0xe000000000000000) != 0:
                self.flags |= FDBinary.FLAG_INVALID_REPRESENTATION
                return 0
            index += 1
        self.flags |= FDBinary.FLAG_OUT_OF_BOUNDS
        return 0

    def get_varint(self):
        zig_zag = self.get_varuint()
        if (zig_zag & 0x0000000000000001) != 0:
            result = -(zig_zag >> 1)
        else:
            result = zig_zag >> 1
        return result

    def get_string(self):
        length = self.get_varuint()
        remaining = self.remaining_length()
        if remaining < length:
            self.flags |= FDBinary.FLAG_INVALID_REPRESENTATION
            length = 0
        buffer = self.data[self.get_index:self.get_index + length]
        string = bytes(buffer).decode('utf-8')
        self.get_index += length
        return string

    def put_check(self, length):
        if not self.limit or ((len(self.data) + length) <= self.limit):
            return True
        self.flags |= FDBinary.FLAG_OVERFLOW
        return False

    def put_bytes(self, data):
        if self.put_check(len(data)):
            self.data += data

    def put_uint8(self, value):
        if self.put_check(1):
            self.data += [value]

    def put_uint16(self, value):
        if self.put_check(2):
            self.data += [value & 0xff, value >> 8]

    def put_uint24(self, value):
        if self.put_check(3):
            self.data += [value & 0xff, (value >> 8) & 0xff, value >> 16]

    def put_uint32(self, value):
        if self.put_check(4):
            self.data += [value & 0xff, (value >> 8) & 0xff, (value >> 16) & 0xff, value >> 24]

    def put_uint64(self, value):
        if self.put_check(8):
            self.data += struct.pack("<Q", value)

    def put_float16(self, value):
        if self.put_check(2):
            self.data += struct.pack("<e", value)

    def put_float32(self, value):
        if self.put_check(4):
            self.data += struct.pack("<f", value)

    def put_float64(self, value):
        if self.put_check(4):
            self.data += struct.pack("<d", value)

    def put_varuint(self, value):
        remainder = value
        while remainder != 0:
            if remainder <= 0x7f:
                break
            byte = remainder | 0x80
            self.put_uint8(byte)
            remainder = remainder >> 7
        byte = remainder
        self.put_uint8(byte)

    def put_varint(self, value):
        if value < 0:
            zig_zag = (-value << 1) | 1
        else:
            zig_zag = value << 1
        self.put_varuint(zig_zag)

    def put_string(self, string):
        buffer = list(string.encode('utf-8'))
        self.put_varuint(len(buffer))
        self.put_bytes(buffer)
