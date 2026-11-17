# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Re-instrument grafana with a filter for Grafana-owned functions
# Maintainer: local only

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal;
    my $bin = '/usr/libexec/grafana/grafana';

    # Drop the unfiltered functions log written by coverage_setup.
    script_run('rm -f /var/coverage/data/*_functions.log /var/coverage/data/*_called.log');
    assert_script_run("funkoverage uninstall $bin", timeout => 300);

    my $count = script_output("funkoverage enumerate --no-libs --include '^github\\.com/grafana/grafana/' $bin | wc -l", timeout => 300);
    record_info('filtered functions', $count);

    assert_script_run("funkoverage install --include '^github\\.com/grafana/grafana/' $bin", timeout => 900);
}

1;
