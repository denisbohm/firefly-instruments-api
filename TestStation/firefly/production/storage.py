import hashlib
from .binary import FDBinary


class Entry:

    def __init__(self, name, sectorCount, length, date, hash, address):
        self.name = name
        self.sectorCount = sectorCount
        self.length = length
        self.date = date
        self.hash = hash
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

    minimumSectorCount = 2 # increase to reduce fragmentation

    size = 1 << 21
    sectorSize = 1 << 12

    pageSize = 1 << 8
    hashSize = 20

    magic = [0xf0, 0x66, 0x69, 0x72, 0x65, 0x66, 0x6c, 0x79]

    sectorCount = size // sectorSize

    def __init__(self, storageInstrument):
        self.storageInstrument = storageInstrument
        self.sectors = []

    def format(self):
        self.storageInstrument.erase(0, FileSystem.size)
        for sector_index in range(len(self.sectors)):
            self.sectors[sector_index].status = Sector.status_available

    def erase_sector(self, sector):
        sectorCount = 1
        if sector.status == Sector.status_metadata:
            sectorCount = sector.entry.sectorCount
        self.storageInstrument.erase(sector.address, self.size)
        firstSectorIndex = sector.address // FileSystem.sectorSize
        for sectorIndex in range(firstSectorIndex, firstSectorIndex + sectorCount):
            self.sectors[sectorIndex].status = Sector.status_available

    def erase(self, name):
        for sector in self.sectors:
            if sector.status == Sector.status_metadata:
                if sector.entry.name == name:
                    self.erase_sector(sector)

    def repair(self):
        repaired = False
        entryByName = {}
        for sector in self.sectors:
            if sector.status == Sector.status_metadata:
                entry = sector.entry
                hash = self.storageInstrument.hash(sector.address + FileSystem.sectorSize, entry.length)
                if hash != entry.hash:
                    print("FileSystem.repair: erasing entry with incorrect content hash: {entry.name}")
                    self.erase_sector(sector)
                    repaired = True
                elif entry.name in entryByName:
                    existing = entryByName[entry.name]
                    print("FileSystem.repair: erasing duplicate entry: {entry.name} {entry.address} {existing.address}")
                    self.erase_sector(sector)
                    repaired = True
                else:
                    entryByName[entry.name] = entry
        return repaired

    def scan(self):
        self.sectors = []
        # read the first byte of each sector so we can quickly probe the status of each
        markers = self.storageInstrument.read(0, FileSystem.sectorCount, 1, FileSystem.sectorSize)
        sectorIndex = 0
        while sectorIndex < FileSystem.sectorCount:
            address = sectorIndex * FileSystem.sectorSize
            marker = markers[sectorIndex]
            if marker == 0xf0:
                # should be metadata
                data = self.storageInstrument.read(address, FileSystem.pageSize)
                if self.magic == data[0:len(self.magic)]:
                    try:
                        binary = FDBinary(data)
                        magic = binary.get_bytes(len(self.magic))
                        usedSectorCount = binary.get_uint32()
                        length = binary.get_uint32()
                        date = binary.get_uint32()
                        hash = binary.get_bytes(FileSystem.hashSize)
                        name = binary.get_string()
                        entry = Entry(name, usedSectorCount, length, date, hash, address + FileSystem.sectorSize)
                        status = Sector.status_metadata
                        sector = Sector(address, status, entry)
                        self.sectors.append(sector)
                        sectorIndex += 1

                        for _ in range(usedSectorCount):
                            address = sectorIndex * FileSystem.sectorSize
                            self.sectors.append(Sector(address, Sector.status_content))
                            sectorIndex += 1
                        continue
                    except:
                        # entry appears to be corrupt, consider this sector available... -denis
                        print("File System: corruption in sector {sectorIndex} entry?")
                # something corrupt found, consider this sector available... -denis
                print("File System: corruption in sector {sectorIndex}?")

            # available
            self.sectors.append(Sector(address, Sector.status_available))
            sectorIndex += 1

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
        return self.storageInstrument.read(entry.address, entry.length)

    def write(self, name, data, date, sector, sectorCount):
        length = len(data)
        hash = hashlib.sha1(data)
        entry = Entry(name, sectorCount, length, date, hash, sector.address + FileSystem.sectorSize)
        sectorIndex = sector.address // FileSystem.sectorSize
        self.sectors[sectorIndex].status = Sector.status_metadata
        self.sectors[sectorIndex].entry = entry
        for _ in range(sectorCount):
            sectorIndex += 1
            self.sectors[sectorIndex].status = Sector.status_content

        self.storageInstrument.erase(sector.address, sectorCount * FileSystem.sectorSize)

        binary = FDBinary()
        binary.put_bytes(self.magic)
        binary.put_uint32(sectorCount)
        binary.put_uint32(length)
        binary.put_uint32(date)
        binary.put_bytes(hash)
        binary.put_string(name)
        address = sector.address
        self.storageInstrument.write(address, binary.data)

        address += FileSystem.sectorSize
        self.storageInstrument.write(address, data)

        return entry

    def checkCandidate(self, name, data, date, availableSector, availableSectorCount, entrySectorCount):
        if availableSector is not None:
            if availableSectorCount >= entrySectorCount:
                return self.write(name, data, date, availableSector, entrySectorCount)
        return None

    def sectorCountForContentLength(self, length):
        return (length + (FileSystem.sectorSize - 1)) // FileSystem.sectorSize

    def checkWrite(self, name, data, date):
        entrySectorCount = max(1 + self.sectorCountForContentLength(len(data)), FileSystem.minimumSectorCount)
        availableSector = None
        availableSectorCount = 0
        for sector in self.sectors:
            if sector.status == Sector.status_available:
                if availableSector is None:
                    availableSector = sector
                    availableSectorCount = 1
                else:
                    availableSectorCount += 1
            else:
                entry = self.checkCandidate(name, data, date, availableSector, availableSectorCount, entrySectorCount)
                if entry is not None:
                    return entry
                availableSector = None
                availableSectorCount = 0
        entry = self.checkCandidate(name, data, date, availableSector, availableSectorCount, entrySectorCount)
        if entry is not None:
            return entry
        return None

    def getLeastRecentlyUsed(self):
        leastRecentlyUsedSector = None
        leastRecentlyUsedDate = None
        for sector in self.sectors:
            if sector.status == Sector.status_metadata:
                if leastRecentlyUsedSector is None:
                    leastRecentlyUsedSector = sector
                    leastRecentlyUsedDate = sector.entry.date
                    continue
                if sector.entry.date < leastRecentlyUsedDate:
                    leastRecentlyUsedSector = sector
                    leastRecentlyUsedDate = sector.entry.date
        return leastRecentlyUsedSector

    def eraseLeastRecentlyUsed(self):
        sector = self.getLeastRecentlyUsed()
        if sector is not None:
            self.erase_sector(sector)
            return True
        return False

    # Allocate a file system entry.
    # The entry is stored in flash before this returns.
    # This will free other (least recently used) entries to make space if needed.
    def write(self, name, data, date):
        while True:
            entry = self.checkWrite(name, data, date)
            if entry is not None:
                return entry
            if not self.eraseLeastRecentlyUsed():
                break
        raise IOError(f"not enough space (name: {name}, length: {len(data)}")

    # This function returns the preexisting entry if the file already exists and the hashes match.
    # Otherwise, the preexisting entry will be removed and a new entry written (possibly removing other least recently used files to make room).
    def ensure(self, name, data, date):
        entry = self.get(name)
        if entry is not None:
            hash = hashlib.sha1(data)
            if hash != entry.hash:
                self.erase(name)
                entry = None
        if entry is None:
            entry = self.write(name, data, date)
            verify = self.storageInstrument.hash(entry.address, entry.length)
            if verify != entry.hash:
                raise IOError("corrupt write")
        return entry
