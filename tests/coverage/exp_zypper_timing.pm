# Throwaway experiment, not for upstream: time a no-op zypper call with and
# without the repositories the agama image ships.
use Mojo::Base 'consoletest';
use testapi;
use serial_terminal 'select_serial_terminal';

sub timed {
    my ($label) = @_;
    my $out = script_output("/usr/bin/time -f 'ELAPSED %e' zypper -n in -l gd 2>&1 | tail -3", timeout => 1200);
    record_info($label, $out);
}

sub run {
    select_serial_terminal;
    record_info('repos', script_output('zypper -n lr -u -P', timeout => 300));
    timed('all repos, 1');
    timed('all repos, 2');
    assert_script_run('zypper -n mr -d OSS NON_OSS OSS_DEBUG', timeout => 300);
    timed('without image repos, 1');
    timed('without image repos, 2');
}

sub test_flags { {fatal => 0} }
1;
