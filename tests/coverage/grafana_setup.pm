# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Prepare grafana-server for binary coverage measurement
# Maintainer: QE Security <none@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'write_sut_file';

sub run {
    select_serial_terminal;
    my $bin = '/usr/libexec/grafana/grafana';

    # The package preset may have started the service before coverage_setup
    # installed the shim. Stop it so the test starts the traced binary.
    script_run('systemctl stop grafana-server');

    # Drop the unfiltered functions log written by coverage_setup; the report
    # unions every functions log.
    script_run('rm -f /var/coverage/data/*_functions.log /var/coverage/data/*_called.log');

    # The binary has 356647 function symbols, mostly dependencies. Trace only
    # Grafana's own code.
    assert_script_run("funkoverage uninstall $bin", timeout => 300);
    assert_script_run("funkoverage install --include '^github\\.com/grafana/grafana/' $bin", timeout => 900);

    # grafana-server.service blocks the shim with an empty capability set and
    # NoNewPrivileges. Its LOG_DIR variable also collides with funkoverage's
    # log directory; a later EnvironmentFile wins over the package one.
    write_sut_file('/etc/sysconfig/grafana-server-coverage', "LOG_DIR=/var/coverage/data\n");
    assert_script_run('mkdir -p /etc/systemd/system/grafana-server.service.d');
    write_sut_file(
        '/etc/systemd/system/grafana-server.service.d/coverage_caps.conf',
        "[Service]\n"
          . "CapabilityBoundingSet=CAP_BPF CAP_PERFMON CAP_DAC_READ_SEARCH CAP_SYS_RESOURCE\n"
          . "NoNewPrivileges=no\n"
          . "TimeoutStartSec=600\n"
          . "TimeoutStopSec=300\n"
          . "KillMode=process\n"
          . "EnvironmentFile=/etc/sysconfig/grafana-server-coverage\n"
    );
    assert_script_run('systemctl daemon-reload');
    script_run('systemctl stop grafana-server');
}

1;
