import hashlib
from .binary import FDBinary


class Entry:

    def __init__(self, name, sector_count, length, date, digest, address):
        self.name = name
        self.sector_count = sector_count
        self.length = length
        self.date = date
        self.digest = digest
        self.address = address


class Sector:

    status_available = 0
    status_metadata = 1
    status_content = 2

    def __init__(self, address, status, entry=None):
        self.address = address
        self.status = status
        self.entry = entry


class FileSystem:

    minimumSectorCount = 2  # increase to reduce fragmentation

    size = 1 << 21
    sectorSize = 1 << 12

# for flash chips we use 256 byte page size
#    pageSize = 1 << 8
# for SD Card we use 512 byte page size (block size)
    pageSize = 1 << 9

    hashSize = 20

    magic = [0xf0, 0x66, 0x69, 0x72, 0x65, 0x66, 0x6c, 0x79]

    sector_count = size // sectorSize

    def __init__(self, storage_instrument):
        self.storage_instrument = storage_instrument
        self.sectors = []

    def format(self):
        self.storage_instrument.erase(0, FileSystem.size)
        for sector_index in range(len(self.sectors)):
            self.sectors[sector_index].status = Sector.status_available

    def erase_sector(self, sector):
        sector_count = 1
        if sector.status == Sector.status_metadata:
            sector_count = sector.entry.sector_count
        self.storage_instrument.erase(sector.address, sector_count * FileSystem.sectorSize)
        first_sector_index = sector.address // FileSystem.sectorSize
        for sector_index in range(first_sector_index, first_sector_index + sector_count):
            self.sectors[sector_index].status = Sector.status_available

    def erase(self, name):
        for sector in self.sectors:
            if sector.status == Sector.status_metadata:
                if sector.entry.name == name:
                    self.erase_sector(sector)

    def repair(self):
        repaired = False
        entry_by_name = {}
        for sector in self.sectors:
            if sector.status == Sector.status_metadata:
                entry = sector.entry
                digest = self.storage_instrument.digest(sector.address + FileSystem.sectorSize, entry.length)
                if digest != entry.digest:
                    print(f"FileSystem.repair: erasing entry with incorrect content digest: {entry.name}")
                    self.erase_sector(sector)
                    repaired = True
                elif entry.name in entry_by_name:
                    existing = entry_by_name[entry.name]
                    print(f"FileSystem.repair: erasing duplicate entry: {entry.name} {entry.address} {existing.address}")
                    self.erase_sector(sector)
                    repaired = True
                else:
                    entry_by_name[entry.name] = entry
        return repaired

    def scan(self):
        self.sectors = []
        # read the first byte of each sector so we can quickly probe the status of each
        markers = self.storage_instrument.read(0, FileSystem.sector_count, 1, FileSystem.sectorSize)
        sector_index = 0
        while sector_index < FileSystem.sector_count:
            address = sector_index * FileSystem.sectorSize
            marker = markers[sector_index]
            if marker == 0xf0:
                # should be metadata
                data = self.storage_instrument.read(address, FileSystem.pageSize)
                if self.magic == data[0:len(self.magic)]:
                    try:
                        binary = FDBinary(data)
                        magic = binary.get_bytes(len(self.magic))
                        sector_count = binary.get_uint32()
                        length = binary.get_uint32()
                        date = binary.get_uint32()
                        digest = binary.get_bytes(FileSystem.hashSize)
                        name = binary.get_string()
                        entry = Entry(name, sector_count, length, date, digest, address + FileSystem.sectorSize)
                        status = Sector.status_metadata
                        sector = Sector(address, status, entry)
                        self.sectors.append(sector)
                        sector_index += 1

                        for _ in range(sector_count):
                            address = sector_index * FileSystem.sectorSize
                            self.sectors.append(Sector(address, Sector.status_content))
                            sector_index += 1
                        continue
                    except:
                        # entry appears to be corrupt, consider this sector available... -denis
                        print("File System: corruption in sector {sector_index} entry?")
                # something corrupt found, consider this sector available... -denis
                print("File System: corruption in sector {sector_index}?")

            # available
            self.sectors.append(Sector(address, Sector.status_available))
            sector_index += 1

    def inspect(self):
        self.scan()
#        self.repair()

    def list(self):
        entries = []
        for sector in self.sectors:
            if sector.status == Sector.status_metadata:
                entries.append(sector.entry)
        return entries

    def get(self, name):
        for sector in self.sectors:
            if sector.status == Sector.status_metadata:
                if sector.entry.name == name:
                    return sector.entry
        return None

    def read(self, name):
        entry = self.get(name)
        if entry is None:
            raise IOError(f"entry not found: {name}")
        return self.storage_instrument.read(entry.address, entry.length)

    def write(self, name, data, date, sector, sector_count):
        length = len(data)
        digest = hashlib.sha1(data)
        entry = Entry(name, sector_count, length, date, digest, sector.address + FileSystem.sectorSize)
        sector_index = sector.address // FileSystem.sectorSize
        self.sectors[sector_index].status = Sector.status_metadata
        self.sectors[sector_index].entry = entry
        for _ in range(sector_count):
            sector_index += 1
            self.sectors[sector_index].status = Sector.status_content

        self.storage_instrument.erase(sector.address, sector_count * FileSystem.sectorSize)

        binary = FDBinary()
        binary.put_bytes(self.magic)
        binary.put_uint32(sector_count)
        binary.put_uint32(length)
        binary.put_uint32(date)
        binary.put_bytes(digest)
        binary.put_string(name)
        address = sector.address
        self.storage_instrument.write(address, binary.data)

        address += FileSystem.sectorSize
        self.storage_instrument.write(address, data)

        return entry

    def check_candidate(self, name, data, date, available_sector, available_sector_count, entry_sector_count):
        if available_sector is not None:
            if available_sector_count >= entry_sector_count:
                return self.write(name, data, date, available_sector, entry_sector_count)
        return None

    def sector_count_for_content_length(self, length):
        return (length + (FileSystem.sectorSize - 1)) // FileSystem.sectorSize

    def check_write(self, name, data, date):
        entry_sector_count = max(1 + self.sector_count_for_content_length(len(data)), FileSystem.minimumSectorCount)
        available_sector = None
        available_sector_count = 0
        for sector in self.sectors:
            if sector.status == Sector.status_available:
                if available_sector is None:
                    available_sector = sector
                    available_sector_count = 1
                else:
                    available_sector_count += 1
            else:
                entry = self.check_candidate(name, data, date, available_sector, available_sector_count, entry_sector_count)
                if entry is not None:
                    return entry
                available_sector = None
                available_sector_count = 0
        entry = self.check_candidate(name, data, date, available_sector, available_sector_count, entry_sector_count)
        if entry is not None:
            return entry
        return None

    def get_least_recently_used(self):
        least_recently_used_sector = None
        least_recently_used_date = None
        for sector in self.sectors:
            if sector.status == Sector.status_metadata:
                if least_recently_used_sector is None:
                    least_recently_used_sector = sector
                    least_recently_used_date = sector.entry.date
                    continue
                if sector.entry.date < least_recently_used_date:
                    least_recently_used_sector = sector
                    least_recently_used_date = sector.entry.date
        return least_recently_used_sector

    def erase_least_recently_used(self):
        sector = self.get_least_recently_used()
        if sector is not None:
            self.erase_sector(sector)
            return True
        return False

    # Allocate a file system entry.
    # The entry is stored in flash before this returns.
    # This will free other (least recently used) entries to make space if needed.
    def allocate(self, name, data, date):
        while True:
            entry = self.check_write(name, data, date)
            if entry is not None:
                return entry
            if not self.erase_least_recently_used():
                break
        raise IOError(f"not enough space (name: {name}, length: {len(data)}")

    # This function returns the preexisting entry if the file already exists and the hashes match.
    # Otherwise, the preexisting entry will be removed and a new entry written (possibly removing
    # other least recently used files to make room).
    def ensure(self, name, data, date):
        entry = self.get(name)
        if entry is not None:
            digest = hashlib.sha1(data)
            if digest != entry.digest:
                self.erase(name)
                entry = None
        if entry is None:
            entry = self.allocate(name, data, date)
            verify = self.storage_instrument.digest(entry.address, entry.length)
            if verify != entry.digest:
                raise IOError("corrupt write")
        return entry
