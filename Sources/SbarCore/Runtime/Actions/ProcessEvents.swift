import Darwin
import Foundation

/// One worker waits; cancellation and mailbox producers may wake it from any thread.
/// The descriptor remains open until all users release this object.
final class ProcessEvents: Sendable {
  private let descriptor: Int32

  init() throws {
    let queue = kqueue()
    guard queue >= 0 else { throw ProcessError.launch(errno) }
    _ = fcntl(queue, F_SETFD, FD_CLOEXEC)
    var event = kevent64_s()
    event.ident = 1
    event.filter = Int16(EVFILT_USER)
    event.flags = UInt16(EV_ADD | EV_CLEAR)
    guard kevent64(queue, &event, 1, nil, 0, 0, nil) == 0 else {
      let code = errno
      close(queue)
      throw ProcessError.launch(code)
    }
    descriptor = queue
  }

  deinit { close(descriptor) }

  func watch(process: pid_t) throws {
    do {
      try register(
        identifier: UInt64(process),
        filter: EVFILT_PROC,
        flags: EV_ADD | EV_ONESHOT,
        notes: NOTE_EXIT
      )
    } catch ProcessError.launch(let code) {
      // A child may already have exited; the worker checks waitpid before waiting.
      if code != ESRCH { throw ProcessError.launch(code) }
    }
  }

  func wake() {
    var event = kevent64_s()
    event.ident = 1
    event.filter = Int16(EVFILT_USER)
    event.fflags = UInt32(NOTE_TRIGGER)
    _ = kevent64(descriptor, &event, 1, nil, 0, 0, nil)
  }

  func wait(read: Int32?, write: Int32? = nil, timeout: Duration? = nil) throws {
    if let read {
      try register(identifier: UInt64(read), filter: EVFILT_READ, flags: EV_ADD | EV_ONESHOT)
    }
    if let write {
      try register(identifier: UInt64(write), filter: EVFILT_WRITE, flags: EV_ADD | EV_ONESHOT)
    }

    var event = kevent64_s()
    let result: Int32
    if let timeout {
      let components = max(.zero, timeout).components
      var deadline = timespec(
        tv_sec: Int(components.seconds),
        tv_nsec: Int(components.attoseconds / 1_000_000_000)
      )
      result = kevent64(descriptor, nil, 0, &event, 1, 0, &deadline)
    } else {
      result = kevent64(descriptor, nil, 0, &event, 1, 0, nil)
    }
    if result < 0 && errno != EINTR { throw ProcessError.launch(errno) }
    if result > 0 && event.flags & UInt16(EV_ERROR) != 0 {
      throw ProcessError.launch(Int32(event.data))
    }
  }

  private func register(identifier: UInt64, filter: Int32, flags: Int32, notes: UInt32 = 0) throws {
    var event = kevent64_s()
    event.ident = identifier
    event.filter = Int16(filter)
    event.flags = UInt16(flags)
    event.fflags = notes
    guard kevent64(descriptor, &event, 1, nil, 0, 0, nil) == 0 else {
      throw ProcessError.launch(errno)
    }
  }
}
