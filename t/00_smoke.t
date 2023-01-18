#!/usr/bin/env perl
use warnings;
use strict;

=head1 Synopsis

Tests for the Perl module File::Replace::Inplace.

=head1 Author, Copyright, and License

Copyright (c) 2017-2023 Hauke Daempfling (haukex@zero-g.net)
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

use Test::More tests=>11; # remember to keep in sync with done_testing

BEGIN {
	diag "This is Perl $] at $^X on $^O";
	BAIL_OUT("Perl 5.8.1 is required") if $] lt '5.008001';
}

use FindBin ();
use lib $FindBin::Bin;
use File_Replace_Testlib;

## no critic (RequireCarping)

BEGIN {
	use_ok('Tie::Handle::Base')
		or BAIL_OUT("failed to use Tie::Handle::Base");
	use_ok('Tie::Handle::Argv')
		or BAIL_OUT("failed to use Tie::Handle::Argv");
	use_ok 'File::Replace'
		or BAIL_OUT("failed to use File::Replace");
	use_ok 'File::Replace::Inplace'
		or BAIL_OUT("failed to use File::Replace::Inplace");
}
is $Tie::Handle::Base::VERSION, '0.16', 'Tie::Handle::Base version matches tests';
is $Tie::Handle::Argv::VERSION, '0.16', 'Tie::Handle::Argv version matches tests';
is $File::Replace::VERSION, '0.16', 'File::Replace version matches tests';
is $File::Replace::Inplace::VERSION, '0.16', 'File::Replace::Inplace version matches tests';

$File::Replace::DISABLE_CHMOD and diag "\n",
	"it appears a simple chmod failed on your system,\n",
	"no attempts to use chmod will be made during testing";

my $fn1 = newtempfn("Hello\nWorld\n");
my $r = File::Replace->new($fn1);
isa_ok $r, 'File::Replace';
while( defined( my $line = readline($r->in_fh) ) ) {
	$line =~ s/o/u/g;
	print {$r->out_fh} $line;
}
ok $r->finish, 'finish';
is slurp($fn1), "Hellu\nWurld\n", 'basic test';

if (my $cnt = grep {!$_} Test::More->builder->summary)
	{ BAIL_OUT("$cnt smoke tests failed") }
done_testing(11);

