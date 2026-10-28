# SUSE's openQA tests
#
# Copyright 2016-2018 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Summary: Cleanup and shutdown after installing or running the LTP
# Maintainer: Richard Palethorpe <rpalethorpe@suse.com>

use 5.018;
use Mojo::Base 'opensusebasetest';
use testapi;
use utils;
use LTP::utils;
use power_action_utils 'prepare_system_shutdown';
use upload_system_log;
use kernel;
use qam;
use Time::HiRes ();

# VR for os-autoinst#3131 only; never to be merged.
sub x3270_screen {
    my $console = console('x3270');
    $console->send_3270('Snap');
    return @{$console->send_3270('Snap(Ascii)')->{command_output}};
}

sub vr_pr3131_poweroff {
    die 'VR pr3131: is_shutdown reported a running guest as shut down' if check_shutdown(30);
    record_info('VR negative', 'check_shutdown(30) returned false while the guest was running');

    prepare_system_shutdown;
    select_console 'root-console' unless current_console() eq 'root-virtio-terminal';
    enter_cmd 'poweroff';
    my $start = Time::HiRes::time();
    my (@timeline, %seen, $last_status, $stopped_at);
    while ((my $elapsed = Time::HiRes::time() - $start) < 600) {
        my @screen = x3270_screen();
        my $status = $screen[-1] // '';
        if (!defined $last_status || $status ne $last_status) {
            push @timeline, sprintf('%6.1f STATUS %s', $elapsed, $status);
            push @timeline, map { "         | $_" } @screen;
            $last_status = $status;
        }
        for my $line (@screen[0 .. $#screen - 2]) {
            next unless $line =~ /Power down|HCPGSP|reboot:|Kernel panic|systemd-shutdown|Reached target|MORE|HOLDING/;
            push @timeline, sprintf('%6.1f LINE   %s', $elapsed, $line) unless $seen{$line}++;
        }
        if ($status =~ /CP READ/) {
            $stopped_at = $elapsed;
            last;
        }
        Time::HiRes::sleep(5);
    }
    mkdir 'ulogs' unless -d 'ulogs';
    open(my $fh, '>', 'ulogs/pr3131-x3270-timeline.txt') or die "cannot write timeline: $!";
    print $fh join("\n", @timeline), "\n";
    close $fh;
    record_info('VR timeline', join("\n", grep { !/^\s+\|/ } @timeline));
    die 'VR pr3131: no CP READ within 600 s after poweroff' unless defined $stopped_at;
    my $t0 = Time::HiRes::time();
    die 'VR pr3131: is_shutdown false although the status line shows CP READ' unless check_shutdown(5);
    record_info('VR positive', sprintf('CP READ after %.1f s, check_shutdown true after %.1f s', $stopped_at, Time::HiRes::time() - $t0));
}

sub export_to_json {
    my ($test_result_export) = @_;
    my $export_file = 'ulogs/result_array.json';

    if (!-d 'ulogs') {
        mkdir('ulogs');
    }
    bmwqemu::save_json_file($test_result_export, $export_file);
}

sub pre_run_hook {
    my ($self) = @_;

    # Kernel error messages should be treated as soft-fail in boot_ltp
    # and install jobs so that at least some testing can be done.
    # But change them to hard fail here if errors will not impact other jobs.
    $self->{serial_failures} = unmask_serial_failures($self->{serial_failures})
      unless has_published_assets();
    $self->SUPER::pre_run_hook;
}

sub run {
    my ($self, $tinfo) = @_;

    if (defined $tinfo) {
        export_to_json($tinfo->test_result_export);
    }

    run_supportconfig;

    script_run('cat /proc/stat');
    script_run('df -h');
    check_kernel_taint($self, has_published_assets() ? 1 : 0);

    if (get_var('LTP_COMMAND_FILE')) {
        my $ver_linux_log = '/tmp/ver_linux_after.txt';
        script_run("\$LTPROOT/ver_linux > $ver_linux_log 2>&1", 120);
        upload_logs($ver_linux_log, failok => 1);
    }

    upload_system_logs();
    check_kernel_package(get_kernel_flavor()) if get_var('INSTALL_LTP');

    # Also cleanup machine-id to avoid duplicate ipv6 link local address in mutli-machine setup.
    script_run('echo -n >/etc/machine-id');

    vr_pr3131_poweroff;
}

sub post_fail_hook {
    select_console('root-console');
    script_run('cat /proc/stat');
}

sub test_flags {
    return {fatal => 1};
}

1;
