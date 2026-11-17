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
    assert_script_run("funkoverage uninstall $bin", timeout => 300);
    assert_script_run("funkoverage install --include '^github\\.com/grafana/grafana/' $bin", timeout => 900);
}

1;
