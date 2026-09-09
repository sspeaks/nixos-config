"""Run an interactive command in an isolated PTY with bounded scripted input."""

import errno
import os
import pty
import select
import signal
import sys
import time


pid, fd = pty.fork()
if pid == 0:
    os.execvp(sys.argv[1], sys.argv[1:])

deadline = time.monotonic() + 30
try:
    response = os.environ.get("TEST_TTY_INPUT", "").encode()
    if response:
        os.write(fd, response)
    while True:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            os.kill(pid, signal.SIGKILL)
            os.waitpid(pid, 0)
            sys.exit("Interactive regression timed out")
        if not select.select([fd], [], [], remaining)[0]:
            continue
        try:
            data = os.read(fd, 65536)
        except OSError as error:
            if error.errno != errno.EIO:
                raise
            break
        if not data:
            break
        sys.stdout.buffer.write(data)
        sys.stdout.buffer.flush()
finally:
    os.close(fd)

_, status = os.waitpid(pid, 0)
sys.exit(os.waitstatus_to_exitcode(status))
