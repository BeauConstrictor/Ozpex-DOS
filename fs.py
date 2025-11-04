import os
import os.path

class Filesystem:
    def __init__(self) -> None:
        self.sectors = [bytearray(256) for i in range(32)]
        
        self.sectors[2][0xfc] = 0xde
        self.sectors[2][0xfd] = 0xad
        self.sectors[2][0xfe] = 0xbe
        self.sectors[2][0xff] = 0xef
        
        self.reserve_sector(0)
        self.reserve_sector(1)
        self.reserve_sector(2)
        
    def reserve_sector(self, index: int) -> int:
        self.sectors[2][index] = 0xff
    def free_sector(self, index: int) -> int:
        self.sectors[2][index] = 0x00
        
    def get_free_sector(self) -> int:
        for idx, s in enumerate(self.sectors[2]):
            if s == 0x00: return idx
        raise MemoryError("There is no space left on the drive.")
        
    def write_file(self, filename: str, data: bytearray) -> None:
        sector = self.get_free_sector()
        self.reserve_sector(sector)
        
        self.store_filename(filename, sector)
        
        index = 0
        
        for b in data:
            if index == 255:
                new_sector = self.get_free_sector()
                self.sectors[sector][255] = new_sector
                sector = new_sector
                self.reserve_sector(sector)
                index = 0
            self.sectors[sector][index] = b
            index += 1
            
        self.sectors[sector][255] = 0x80
        
    def store_filename(self, filename: str, sector: int) -> None:
        extension = filename.split(".")[-1]
        filename = ".".join(filename.split(".")[:-1]).ljust(12, " ")
        
        index = 0
        
        while True:
            if self.sectors[0][index] != 0x00:
                index += 16
                continue
            for ch in filename + extension:
                self.sectors[0][index] = ord(ch)
                index += 1
            self.sectors[0][index] = sector
            index += 1
            return
        raise MemoryError("There is no space left on the drive.")
        
    def export(self) -> bytearray:
        image = bytearray()
        for sector in self.sectors:
            image.extend(sector)
        return image
    
if __name__ == "__main__":
    fs = Filesystem()
    
    for fname in os.listdir("imgs"):
        with open(os.path.join("imgs", fname), "rb") as f:
            fs.write_file(fname, f.read())
            
    with open("README.md", "rb") as f:
            fs.write_file("manual.txt", f.read())
    
    with open("../ozpex-64/bbrams/o64dos-fs.bin", "wb") as f:
        f.write(fs.export())