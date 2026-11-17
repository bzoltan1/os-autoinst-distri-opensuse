# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Start/stop grafana-server under the shim and upload flush diagnostics
# Maintainer: local only

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'systemctl';

sub run {
    select_serial_terminal;

    # The package preset may have started the service before the shim was
    # installed. Restart it so systemd runs the shim.
    script_run('systemctl stop grafana-server');
    systemctl('start grafana-server');
    assert_script_run('curl -sf --retry 120 --retry-delay 5 --retry-all-errors http://localhost:3000/api/health', timeout => 700);
    assert_script_run('curl -s http://localhost:3000/api/health >/dev/null');
    systemctl('stop grafana-server');
    sleep 15;

    assert_script_run('journalctl -u grafana-server --no-pager > /tmp/grafana-journal.txt');
    upload_logs('/tmp/grafana-journal.txt', failok => 1);
    assert_script_run('ls -l /var/coverage/data > /tmp/coverage-data.txt');
    upload_logs('/tmp/coverage-data.txt', failok => 1);
    assert_script_run('for f in /var/coverage/data/*_called.log; do [ -e "$f" ] && { echo "== $f"; wc -l "$f"; head -5 "$f"; }; done > /tmp/called-summary.txt');
    upload_logs('/tmp/called-summary.txt', failok => 1);
    assert_script_run('for f in /var/coverage/data/*_functions.log; do [ -e "$f" ] && { echo "== $f"; wc -l "$f"; }; done > /tmp/functions-summary.txt');
    upload_logs('/tmp/functions-summary.txt', failok => 1);
}

1;
