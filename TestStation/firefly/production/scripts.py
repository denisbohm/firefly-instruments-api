import time
from .instruments import InstrumentManager
from .storage import FileSystem


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
        return self.presenter.is_cancelling();

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
