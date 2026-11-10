# Copyright SUSE LLC
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Summary: throwaway probe, time instrumented zypper under repo configs
# Maintainer: Zoltan Balogh <zbalogh@suse.com>

use Mojo::Base 'opensusebasetest';
use testapi;
use utils 'write_sut_file';
use serial_terminal 'select_serial_terminal';

sub run {
    select_serial_terminal;
    write_sut_file('/tmp/zt.sh', <<'SH');
TIMEFORMAT=%R
t() { local label=$1; shift; local s; s=$( { time "$@" >/dev/null 2>&1; } 2>&1 ); echo "T $label $s rc=$?"; }
zypper lr -d
for rep in 1 2 3; do
  t version zypper --version
  t in_default zypper -n in nano
  t in_norefresh zypper -n --no-refresh in nano
  t info_default zypper -n info nano
  zypper -n mr -d debug >/dev/null
  t in_nodebug zypper -n in nano
  t in_nodebug_norefresh zypper -n --no-refresh in nano
  zypper -n mr -e debug >/dev/null
done
SH
    assert_script_run('bash /tmp/zt.sh > /tmp/zt.log 2>&1', timeout => 3600);
    upload_logs('/tmp/zt.log');
    record_info('timings', script_output('grep ^T /tmp/zt.log'));
}

1;
