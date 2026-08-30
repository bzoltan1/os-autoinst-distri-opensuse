# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Collect ftrace exec data and produce a binary execution inventory
# Maintainer: QE Core <qe-core@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal;

    # Stop tracing
    script_run('echo 0 > /sys/kernel/tracing/tracing_on', timeout => 10);

    # Extract filenames from sched_process_exec events
    # Format: "filename=/usr/bin/foo pid=1234 old_pid=1233"
    script_run(
        q{grep -oP 'filename=\K\S+' /sys/kernel/tracing/trace | sort | uniq -c | sort -rn > /tmp/execve_inventory.txt},
        timeout => 600
    );

    # Count
    my $count = script_output('wc -l < /tmp/execve_inventory.txt', timeout => 30);
    record_info('Inventory', "$count unique binaries executed");

    # Show top 50
    my $top = script_output('head -50 /tmp/execve_inventory.txt', timeout => 30);
    record_info('Top 50', $top);

    # Filter to ELF binaries, excluding coreutils/shell noise
    script_run(
        q{awk '{print $2}' /tmp/execve_inventory.txt | while read bin; do }
        . q{[ -f "$bin" ] && file -b "$bin" 2>/dev/null | grep -q ELF && echo "$bin"; }
        . q{done > /tmp/execve_elf_binaries.txt},
        timeout => 600
    );

    my $elf_count = script_output('wc -l < /tmp/execve_elf_binaries.txt', timeout => 30);
    record_info('ELF binaries', "$elf_count unique ELF binaries executed");

    # Upload both files
    upload_logs('/tmp/execve_inventory.txt');
    upload_logs('/tmp/execve_elf_binaries.txt');
}

sub test_flags {
    return {fatal => 0};
}

1;
