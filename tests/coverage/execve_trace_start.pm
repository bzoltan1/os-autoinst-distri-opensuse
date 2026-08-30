# Copyright SUSE LLC
# SPDX-License-Identifier: FSFAP

# Summary: Enable ftrace execve tracing to capture all binary executions
# Maintainer: QE Core <qe-core@suse.de>

use Mojo::Base 'opensusebasetest';
use testapi;
use serial_terminal 'select_serial_terminal';
use utils 'zypper_call';
use scheduler 'get_test_suite_data';

sub run {
    select_serial_terminal;

    # Add repos for package resolution
    script_run 'zypper ar -e -f -p 1 http://download.opensuse.org/tumbleweed/repo/oss/ main';
    script_run 'zypper ar -e -f -p 1 http://download.opensuse.org/update/tumbleweed/ update';
    script_run 'zypper ar -e -f -p 1 http://download.opensuse.org/repositories/devel:/tools/openSUSE_Tumbleweed devtools';
    # Force refresh to avoid stale metadata
    assert_script_run 'zypper --gpg-auto-import-keys ref --force', timeout => 300;

    # Install all packages from coverage_targets + helpers
    my $test_data = get_test_suite_data();
    my @packages;
    if ($test_data && $test_data->{coverage_targets}) {
        push @packages, keys %{$test_data->{coverage_targets}};
    }
    if ($test_data && $test_data->{helper_packages}) {
        push @packages, @{$test_data->{helper_packages}};
    }

    # Install in chunks
    while (@packages) {
        my @chunk = splice(@packages, 0, 20);
        zypper_call('--gpg-auto-import-keys in ' . join(' ', @chunk), exitcode => [0, 104, 106]);
    }

    # Set SELinux to permissive -- same as coverage_setup.pm.
    # Enforcing mode blocks SSH port forwarding and other test operations.
    script_run('setenforce 0');

    # Use ftrace to trace sched_process_exec events
    # This is near-zero overhead -- the kernel writes to a ring buffer
    # and we only read it at the end
    assert_script_run('mount -t tracefs tracefs /sys/kernel/tracing 2>/dev/null; true');
    assert_script_run('echo 0 > /sys/kernel/tracing/tracing_on');
    # 16MB per CPU buffer (32MB total with QEMUCPUS=2) -- enough for exec events
    assert_script_run('echo 16384 > /sys/kernel/tracing/buffer_size_kb');
    assert_script_run('echo > /sys/kernel/tracing/trace');
    assert_script_run('echo 1 > /sys/kernel/tracing/events/sched/sched_process_exec/enable');
    assert_script_run('echo 1 > /sys/kernel/tracing/tracing_on');
    record_info('Tracing', 'ftrace sched_process_exec enabled (128MB ring buffer)');
}

sub test_flags {
    return {fatal => 1};
}

1;
