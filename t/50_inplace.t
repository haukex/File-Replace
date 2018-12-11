#!/usr/bin/env perl
use warnings;
use strict;

=head1 Synopsis

Tests for the Perl module File::Replace::Inplace.

=head1 Author, Copyright, and License

Copyright (c) 2018 Hauke Daempfling (haukex@zero-g.net)
at the Leibniz Institute of Freshwater Ecology and Inland Fisheries (IGB),
Berlin, Germany, L<http://www.igb-berlin.de/>

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see L<http://www.gnu.org/licenses/>.

=cut

use FindBin ();
use lib $FindBin::Bin;
use File_Replace_Testlib;

use Test::More; #TODO Later: tests=>1;

use File::Spec::Functions qw/catdir/;
use IPC::Run3::Shell 0.56 ':FATAL', [ perl => { fail_on_stderr=>1,
	show_cmd=>Test::More->builder->output },
	$^X, '-I'.catdir($FindBin::Bin,'..','lib') ];

## no critic (RequireCarping)

BEGIN {
	use_ok 'File::Replace::Inplace';
	use_ok 'File::Replace', 'inplace';
}

subtest 'basic test' => sub {
	my @tmpfiles = (newtempfn("Foo\nBar"), newtempfn("Quz\nBaz\n"));
	local @ARGV = @tmpfiles;
	local $ARGV = "foobar";
	my $oldargvout = \*ARGVOUT;
	my $oldargv = \*ARGV;
	{
		my $inpl = File::Replace::Inplace->new();
		while (<>) {
			print "$ARGV:$.: ".uc;
		}
	}
	is slurp($tmpfiles[0]), "$tmpfiles[0]:1: FOO\n$tmpfiles[0]:2: BAR", 'file 1 correct';
	is slurp($tmpfiles[1]), "$tmpfiles[1]:3: QUZ\n$tmpfiles[1]:4: BAZ\n", 'file 2 correct';
	is @ARGV, 0, '@ARGV empty';
	is $ARGV, 'foobar', '$ARGV restored';
	is \*ARGVOUT, $oldargvout, '$ARGVOUT restored';
	is \*ARGV, $oldargv, '$ARGV restored';
};

subtest 'inplace()' => sub {
	my @tmpfiles = (newtempfn("X\nY\nZ"), newtempfn("AA\nBB\nCC\n"));
	my @files = @tmpfiles;
	local @ARGV = ('foo','bar');
	{
		my $inpl = inplace( files=>\@files );
		print "$ARGV:$.:$_" while <>;
	}
	is_deeply \@ARGV, ['foo','bar'], '@ARGV unaffected';
	is @files, 0, '@files was emptied';
	is slurp($tmpfiles[0]), "$tmpfiles[0]:1:X\n$tmpfiles[0]:2:Y\n$tmpfiles[0]:3:Z", 'file 1 correct';
	is slurp($tmpfiles[1]), "$tmpfiles[1]:4:AA\n$tmpfiles[1]:5:BB\n$tmpfiles[1]:6:CC\n", 'file 2 correct';
};

subtest 'backup' => sub {
	my $tfn = newtempfn("Foo\nBar");
	my $bfn = $tfn.'.bak';
	{
		ok !-e $bfn, 'backup file doesn\'t exist yet';
		my $inpl = File::Replace::Inplace->new( files=>[$tfn], backup=>'.bak' );
		print "$ARGV+$.+$_" while <>;
	}
	is slurp($tfn), "$tfn+1+Foo\n$tfn+2+Bar", 'file edited correctly';
	is slurp($bfn), "Foo\nBar", 'backup file correct';
};

subtest 'cmdline' => sub {
	my @tmpfiles = (newtempfn("One\nTwo\n"), newtempfn("Three\nFour"));
	is perl('-MFile::Replace=-i','-pe','s/[aeiou]/_/gi', @tmpfiles), '', 'no output';
	is slurp($tmpfiles[0]), "_n_\nTw_\n", 'file 1 correct';
	is slurp($tmpfiles[1]), "Thr__\nF__r", 'file 2 correct';
	my @bakfiles = map { "$_.bak" } @tmpfiles;
	ok !-e $bakfiles[0], 'backup 1 doesn\'t exist';
	ok !-e $bakfiles[1], 'backup 2 doesn\'t exist';
	is perl('-MFile::Replace=-i.bak','-nle','print "$ARGV:$.: $_"', @tmpfiles), '', 'no output (2)';
	is slurp($tmpfiles[0]), "$tmpfiles[0]:1: _n_\n$tmpfiles[0]:2: Tw_\n", 'file 1 correct (2)';
	is slurp($tmpfiles[1]), "$tmpfiles[1]:3: Thr__\n$tmpfiles[1]:4: F__r\n", 'file 2 correct (2)';
	is slurp($bakfiles[0]), "_n_\nTw_\n", 'backup file 1 correct';
	is slurp($bakfiles[1]), "Thr__\nF__r", 'backup file 2 correct';
};

#TODO: Tests for:
# - @ARGV being initially empty (STDIN->STDOUT)
# - @ARGV containing "-" (shouldn't work)
# - emptying out @ARGV and re-starting

done_testing;
