# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Allow the funkoverage shim to run under grafana-server hardening
# Maintainer: local only

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'write_sut_file';

sub run {
    select_serial_terminal;
    assert_script_run('mkdir -p /etc/systemd/system/grafana-server.service.d');
    write_sut_file('/etc/sysconfig/grafana-server-coverage', "LOG_DIR=/var/coverage/data\n");
    write_sut_file(
        '/etc/systemd/system/grafana-server.service.d/coverage_caps.conf',
        "[Service]\nCapabilityBoundingSet=CAP_BPF CAP_PERFMON CAP_DAC_READ_SEARCH CAP_SYS_RESOURCE\nNoNewPrivileges=no\nTimeoutStartSec=600\nTimeoutStopSec=300\nKillMode=process\nEnvironmentFile=/etc/sysconfig/grafana-server-coverage\nEnvironment=FUNKOVERAGE_DEBUG=1\n"
    );
    assert_script_run('systemctl daemon-reload');
    script_run('systemctl stop grafana-server');
}

1;
