# SUSE's openQA tests
#
# Copyright 2021 SUSE LLC
# SPDX-License-Identifier: FSFAP

# Package: irqbalance
# Summary: Test irqbalance runs as service as well as standalone
# Maintainer: Pavel Dostál <pdostal@suse.cz>

use Mojo::Base 'consoletest';
use testapi qw(is_serial_terminal :DEFAULT);
use serial_terminal 'select_serial_terminal';
use utils qw(systemctl zypper_call clear_console);
use Utils::Backends 'is_qemu';

sub run {
    select_serial_terminal;

    # Skip when balancing is ineffective on system with a single cpu
    my $nproc = script_output('cat /proc/cpuinfo | grep processor | wc -l');
    unless ($nproc > 1) {
        record_info('SKIP', "Balancing is ineffective on systems with a single cpu (nproc=$nproc)");
        return;
    }

    zypper_call("in irqbalance");
    systemctl('enable --now irqbalance.service');

    # Generate CPU load
    assert_script_run('dd if=/dev/urandom of=/dev/null count=30 bs=16M iflag=fullblock', 90);

    # Test that local timer interrupts are distributed over CPUs
    my @locs = split(' ', script_output("grep 'LOC' /proc/interrupts | sed -E -e 's/[[:blank:]]+/ /g' | cut -d' ' -f 2-\$((${nproc}+1))"));
    for (my $i = 0; $i < $nproc; $i++) {
        next if ($locs[$i] > 0);
        # QEMU may keep local timer interrupts on CPU0
        if (is_qemu) {
            record_info('SKIP', "CPU" . ($i + 1) . " has no local timer interrupts on QEMU");
            last;
        }
        die("The value of local timer interrupts for CPU" . ($i + 1) . " is 0");
    }

    systemctl('stop irqbalance.service');

    # Test that irqbalance succeeds as standalone application
    assert_script_run('irqbalance --oneshot --debug', 360);

    # start irqbalance.service again
    systemctl('start irqbalance.service');

    # Clear the remains from background commands
    clear_console if !is_serial_terminal;
}

sub test_flags {
    return {fatal => 0, no_rollback => 1};
}

1;
