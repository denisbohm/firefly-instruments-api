import tkinter as tk
import tkinter.scrolledtext as scrolledtext
from tkmacosx import Button
import threading
import ctypes
import os
import sys
import traceback
from .scripts import Fixture
from .scripts import Script


class ThreadCancelException(Exception):

    def __init__(self):
        super().__init__()


class Runner(threading.Thread):

    def __init__(self, presenter, fixture, script):
        super().__init__()
        self.presenter = presenter
        self.fixture = fixture
        self.script = script
        self.cancelling = False

    def cancel(self):
        self.cancelling = True
        if not self.is_alive():
            return
        thread_id = ctypes.c_long(self.ident)
        exception = ctypes.py_object(ThreadCancelException)
        threads_affected = ctypes.pythonapi.PyThreadState_SetAsyncExc(thread_id, exception)
        if threads_affected != 1:
            # if it returns a number greater than one, you're in trouble,
            # and you should call it again with exc=NULL to revert the effect
            ctypes.pythonapi.PyThreadState_SetAsyncExc(thread_id, None)
            raise SystemError("PyThreadState_SetAsyncExc failed")

    def run(self):
        try:
            self.script.main()
        except ThreadCancelException:
            self.script.status = Script.status_cancelled
        except Exception as exception:
            self.script.status = Script.status_cancelled
            exception_type, exception_value, exception_traceback = sys.exc_info()
            detail = f"{exception_type.__name__}: {exception_value}\nStack Trace:"
            for frame in traceback.extract_tb(exception_traceback):
                detail += f"\n at {frame.name} in {os.path.basename(frame.filename)} line {frame.lineno}: {frame.line}"
            self.presenter.log(detail, "fail")
        self.presenter.completed()


class TestStation:

    def __init__(self, create_script):
        self.create_script = create_script

        self.window = None
        self.font = None
        self.startButton = None
        self.cancelButton = None
        self.logText = None
        self.logVerticalScrollbar = None

        self.runner = None
        self.script = None
        self.fixture = None

    def add_log(self):
        self.logText = scrolledtext.ScrolledText(state='disabled', wrap='none')
        self.logText['state'] = 'disabled'
        self.logText.tag_configure('information')
        self.logText.tag_configure('pass', background='green')
        self.logText.tag_configure('fail', background='red', foreground='white')
        self.log("Ready...")

    def add_buttons(self):
        self.startButton = Button(text='Start', command=self.start_button_command, borderless=True)
        self.cancelButton = Button(text='Cancel', command=self.cancel_button_command, borderless=True)
        self.cancelButton['state'] = 'disabled'

    def layout(self):
        tk.Grid.columnconfigure(self.window, 1, weight=1)
        tk.Grid.rowconfigure(self.window, 1, weight=1)
        self.startButton.grid(row=0, column=0, sticky='W')
        self.cancelButton.grid(row=0, column=2, sticky='E')
        self.logText.grid(row=1, column=0, columnspan=3, sticky='NSEW')

    def open(self):
        self.window = tk.Tk()
        self.window.title('Test Station')
        self.window.minsize(400, 400)
        self.window.geometry('800x800')

        self.add_buttons()
        self.add_log()
        self.layout()

        self.window.mainloop()

    def start_button_command(self):
        self.startButton['state'] = 'disabled'
        self.cancelButton['state'] = 'normal'
        self.log_clear()

        self.log('Running...')
        self.fixture = Fixture(self)
        self.script = self.create_script()
        self.runner = Runner(self, self.fixture, self.script)
        self.runner.start()

    def cancel_button_command(self):
        self.log('Cancelling...', 'fail')
        self.runner.cancel()

    def log_clear(self):
        self.logText['state'] = 'normal'
        self.logText.delete('1.0', 'end')
        self.logText['state'] = 'disabled'

    def log_on_main_thread(self, message, tag):
        self.logText['state'] = 'normal'
        self.logText.insert('end', message, tag)
        self.logText.insert('end', '\n')
        self.logText.see('end')
        self.logText['state'] = 'disabled'

    def log(self, message, tag='information'):
        self.window.after(0, self.log_on_main_thread, message, tag)

    def completed_on_main_thread(self):
        if self.script.status == Script.status_pass:
            self.log('Pass', 'pass')
        elif self.script.status == Script.status_fail:
            self.log('Fail!', 'fail')
        elif self.script.status == Script.status_cancelled:
            self.log('Script cancelled!', 'fail')
        else:
            self.log('Script exception!', 'fail')
        self.startButton['state'] = 'normal'
        self.cancelButton['state'] = 'disabled'

    def completed(self):
        self.window.after(0, self.completed_on_main_thread)

    def is_cancelling(self):
        return self.runner.cancelling
