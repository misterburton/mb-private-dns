#!/bin/bash
# Fixed lifecycle operations for this product only. Run with administrator authorization.
set -euo pipefail
helper='/Library/PrivilegedHelperTools/local-private-dns-helper'
job='system/local.private-dns.resolver'
plist='/Library/LaunchDaemons/local.private-dns.resolver.plist'
engine='^/Library/Application Support/Private DNS/Runtime/dnscrypt-proxy( |$)'
[ "$EUID" -eq 0 ] || { echo 'Administrator authorization is required.' >&2; exit 1; }
case "${1:-}" in
    stop)
        # Restore DNS before removing the resolver that currently answers it.
        "$helper" --command 'pause reboot' >/dev/null
        /bin/launchctl bootout "$job"
        /usr/bin/pkill -TERM -f "$engine" || [ "$?" -eq 1 ]
        for attempt in {1..5}; do
            if ! /usr/bin/pgrep -f "$engine" >/dev/null; then break; fi
            /bin/sleep 1
        done
        if /usr/bin/pgrep -f "$engine" >/dev/null; then
            /usr/bin/pkill -KILL -f "$engine"
            /bin/sleep 1
        fi
        if /usr/bin/pgrep -f "$engine" >/dev/null || /bin/launchctl print "$job" >/dev/null 2>&1; then
            echo 'Private DNS did not fully stop. The controls will remain open.' >&2
            exit 1
        fi
        echo 'Private DNS stopped. Network-provided DNS is active.'
        ;;
    start)
        if ! /bin/launchctl print "$job" >/dev/null 2>&1; then
            /bin/launchctl bootstrap system "$plist"
        fi
        for attempt in {1..20}; do
            if "$helper" --command status >/dev/null 2>&1; then
                "$helper" --command on
                exit 0
            fi
            /bin/sleep 1
        done
        echo 'Private DNS could not start. Reopen the app to retry.' >&2
        exit 1
        ;;
    *) echo 'Unsupported lifecycle action.' >&2; exit 1 ;;
esac
