# SUSE's openQA tests
#
# Copyright 2020 SUSE LLC
# SPDX-License-Identifier: FSFAP
#
# Package: sharutils diffutils
# Summary: This will test the shar (SHELL ARCHIVE) tool
# Maintainer: Dominik Heidler <dominik@heidler.eu>

use Mojo::Base 'consoletest';
use testapi;
use utils;
use version_utils;
use package_utils 'install_package';
use serial_terminal 'select_serial_terminal';

sub run {
    my $self = shift;

    select_console 'root-console';
    install_package('sharutils', trup_reboot => 1);

    if (check_var('MACHINE', 'RPi3') || check_var('MACHINE', 'RPi4')) {
        select_console 'root-console';
        install_package('diffutils', trup_reboot => 1);
    }

    select_console 'user-console';
    assert_script_run('curl -o /tmp/shar_testdata.sh ' . data_url('shar_testdata.sh'));
    assert_script_run('sh /tmp/shar_testdata.sh');
    assert_script_run('file shar_testdata/suse.png | grep "600 x 550"');
    assert_script_run('head -1 shar_testdata/hallo.txt | grep "Hallo Welt"');
    assert_script_run('shar shar_testdata > a.sh');
    assert_script_run('mkdir a');
    assert_script_run('unshar -d a a.sh');
    assert_script_run('diff -ru shar_testdata a/shar_testdata');
}

sub post_fail_hook {
    my ($self) = @_;
    $self->SUPER::post_fail_hook;
    # A timed out shar or unshar keeps the user console busy for later modules.
    select_serial_terminal;
    script_run("pkill -u $testapi::username -f shar");
    script_run("rm -rf /home/$testapi::username/{shar_testdata,a,a.sh} /tmp/shar_testdata.sh");
}

sub test_flags {
    my ($self) = @_;
    # Keep the instrumented system and its coverage data instead of aborting.
    return {fatal => 0, no_rollback => 1} if get_var('BINARY_COVERAGE');
    return $self->SUPER::test_flags();
}

1;
