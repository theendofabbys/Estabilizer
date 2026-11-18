#!/usr/bin/env bash
export TERM=xterm

MARKER=""
READY=""
CMD_FILE=""
PY_FILE=""
EX_FILE=""
RB_FILE=""

one() {
    for x in "$@"; do
        command -v "$x" >/dev/null 2>&1 && { printf '%s' "$x"; return 0; }
    done
    return 1
}

two() {
    local c
    for c in /bin/bash /usr/bin/bash /bin/zsh /usr/bin/zsh /bin/ash /bin/dash /bin/sh; do
        [ -x "$c" ] && { printf '%s' "$c"; return 0; }
    done
    printf '%s' /bin/sh
}

three() {
    local s r c
    s=$(stty size 2>/dev/null || true)
    set -- $s
    r="${1:-0}"
    c="${2:-0}"
    case "$r" in ''|*[!0-9]*) r=0 ;; esac
    case "$c" in ''|*[!0-9]*) c=0 ;; esac
    if [ "$r" -eq 0 ] || [ "$c" -eq 0 ]; then
        r="${LINES:-0}"
        c="${COLUMNS:-0}"
    fi
    case "$r$c" in ''|*[!0-9]*) r=24; c=80 ;; esac
    [ "$r" -gt 0 ] || r=24
    [ "$c" -gt 0 ] || c=80
    ROWS="$r"
    COLS="$c"
}

eleven() {
    rm -f "$MARKER" "$READY" "$CMD_FILE" "$PY_FILE" "$EX_FILE" "$RB_FILE" 2>/dev/null
}

twelve() {
    local py="$1"
    [ -n "$py" ] || return 1
    "$py" -c 'import pty,sys; pty.spawn([sys.argv[1]])' "$CMD_FILE"
}

four() {
    SH=$(two)
    three

    local base="/tmp/.st.$$.${RANDOM}"
    MARKER="${base}.m"
    READY="${base}.y"
    CMD_FILE="${base}.c"
    PY_FILE="${base}.p"
    EX_FILE="${base}.e"
    RB_FILE="${base}.r"

    : > "$CMD_FILE" 2>/dev/null || { eleven; return 1; }
    : > "$PY_FILE" 2>/dev/null || { eleven; return 1; }
    : > "$EX_FILE" 2>/dev/null || { eleven; return 1; }
    : > "$RB_FILE" 2>/dev/null || { eleven; return 1; }
    rm -f "$MARKER" "$READY" 2>/dev/null

    printf '#!/bin/sh\n: > "%s"\nexport TERM=xterm\nstty sane 2>/dev/null\nstty rows %s cols %s 2>/dev/null\n[ -t 0 ] && [ -t 1 ] || exit 1\n: > "%s"\nexec "%s" -i\n' \
        "$MARKER" "$ROWS" "$COLS" "$READY" "$SH" > "$CMD_FILE" || { eleven; return 1; }
    chmod +x "$CMD_FILE" 2>/dev/null || { eleven; return 1; }

    cat > "$EX_FILE" <<'EOF' || { eleven; return 1; }
set cmd [lindex $argv 0]
spawn $cmd
interact
EOF

    cat > "$RB_FILE" <<'EOF' || { eleven; return 1; }
require 'pty'
require 'timeout'
cmd = ARGV[0]
mark = ARGV[1]
ready = ARGV[2]
out = nil
begin
  PTY.spawn(cmd) do |r, w, pid|
    File.open(mark, 'w') {}
    File.open(ready, 'w') {}
    out = Thread.new do
      loop { $stdout.write(r.readpartial(4096)) }
    end
    begin
      loop { w.write($stdin.readpartial(4096)) }
    rescue EOFError, Errno::EIO, IOError
      begin
        w.write("\x04")
      rescue Exception
      end
    end
    begin
      Timeout.timeout(2) { out.join }
    rescue Timeout::Error
      begin
        Process.kill('TERM', pid)
      rescue Exception
      end
      begin
        out.join
      rescue Exception
      end
    rescue Exception
    end
    begin
      out.kill
    rescue Exception
    end
    begin
      w.close
    rescue Exception
    end
  end
rescue Exception
  begin
    out.kill if out
  rescue Exception
  end
end
EOF
}

five() {
    local py="$1"
    [ -n "$py" ] || return 1
    cat > "$PY_FILE" <<'PY'
import os,sys,pty,termios,struct,fcntl,select
sh=sys.argv[1]; r=int(sys.argv[2]); c=int(sys.argv[3]); mark=sys.argv[4]; ready=sys.argv[5]
pid,fd=pty.fork()
if pid==0: os.execv(sh,[sh,"-i"])
try: fcntl.ioctl(fd,termios.TIOCSWINSZ,struct.pack("HHHH",r,c,0,0))
except OSError: pass
open(mark,"w").close()
if os.isatty(fd): open(ready,"w").close()
eof=False
while True:
    fds=[fd] if eof else [0,fd]
    try: f,_,_=select.select(fds,[],[])
    except (OSError,ValueError,InterruptedError): continue
    done=False
    for s in f:
        if s==0:
            try: d=os.read(0,4096)
            except OSError: d=b""
            if not d:
                eof=True
                try: os.write(fd,b"\x04")
                except OSError: pass
                continue
            try: os.write(fd,d)
            except OSError: pass
        else:
            try: d=os.read(fd,4096)
            except OSError:
                done=True
                break
            if not d:
                done=True
                break
            try: os.write(1,d)
            except OSError: pass
    if done: break
try: os.waitpid(pid,0)
except OSError: pass
PY
    "$py" "$PY_FILE" "$SH" "$ROWS" "$COLS" "$MARKER" "$READY"
}

six() {
    if command -v script >/dev/null 2>&1; then
        if script -q -c 'true' /dev/null >/dev/null 2>&1; then
            script -q -c "$CMD_FILE" /dev/null
            return
        fi
        if script -q /dev/null true >/dev/null 2>&1; then
            script -q /dev/null "$CMD_FILE"
            return
        fi
    fi

    if command -v busybox >/dev/null 2>&1; then
        if busybox script -q -c 'true' /dev/null >/dev/null 2>&1; then
            busybox script -q -c "$CMD_FILE" /dev/null
        else
            busybox script -q /dev/null "$CMD_FILE"
        fi
    fi
}

seven() {
    local sc
    sc=$(one socat) || return 1
    "$sc" - "EXEC:${CMD_FILE},pty,stderr,setsid,sigint,sane"
}

eight() {
    local ex
    ex=$(one expect) || return 1
    "$ex" -f "$EX_FILE" "$CMD_FILE"
}

nine() {
    local rb
    rb=$(one ruby) || return 1
    "$rb" "$RB_FILE" "$CMD_FILE" "$MARKER" "$READY"
}

ten() {
    local py
    for py in python3 python python2; do
        command -v "$py" >/dev/null 2>&1 || continue
        rm -f "$MARKER" "$READY" 2>/dev/null
        twelve "$py"
        [ -f "$READY" ] && exit 0
        rm -f "$MARKER" "$READY" 2>/dev/null
        five "$py"
        [ -f "$READY" ] && exit 0
        break
    done

    local fn
    for fn in six seven eight nine; do
        rm -f "$MARKER" "$READY" 2>/dev/null
        "$fn"
        [ -f "$READY" ] && exit 0
    done

    exec "$SH" -i
}

trap eleven EXIT
trap 'exit 143' TERM
trap 'exit 130' INT
trap 'exit 129' HUP

four || exec "$SH" -i
ten
