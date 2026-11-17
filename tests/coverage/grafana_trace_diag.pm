# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Run grafana under funkoverage trace with debug logging
# Maintainer: local only

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal;
    my $bin = '/usr/libexec/grafana/grafana';
    script_run('rm -f /var/coverage/data/*_functions.log /var/coverage/data/*_called.log');
    assert_script_run("funkoverage uninstall $bin", timeout => 300);
    my $rc = script_run("FUNKOVERAGE_DEBUG=1 funkoverage trace --include '^github\\.com/grafana/grafana/' $bin --version > /tmp/trace.out 2>&1", timeout => 600);
    record_info('trace rc', defined $rc ? $rc : 'undef');
    upload_logs('/tmp/trace.out', failok => 1);
}

1;
