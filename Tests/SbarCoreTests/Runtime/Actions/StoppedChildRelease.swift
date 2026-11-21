import Darwin
import os

/// Returns a runner exit-check hook for children that stop themselves before writing.
/// On the first check, after the runner has found no output, it resumes the child and
/// waits, without reaping, until the child has written its output and exited.
func releaseStoppedChildBeforeExitCheck() -> @Sendable (pid_t) -> Void {
  let released = OSAllocatedUnfairLock(initialState: false)

  return { pid in
    let first = released.withLock { released in
      defer { released = true }
      return !released
    }
    guard first else { return }

    var info = siginfo_t()
    while waitid(P_PID, id_t(pid), &info, WSTOPPED | WNOWAIT) < 0 && errno == EINTR {}
    kill(pid, SIGCONT)
    while waitid(P_PID, id_t(pid), &info, WEXITED | WNOWAIT) < 0 && errno == EINTR {}
  }
}
