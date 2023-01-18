#!/usr/bin/env perl
use warnings;
use strict;

=head1 Synopsis

Tests for the Perl module Tie::Handle::Argv.

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

use Test::More;

use Cwd qw/getcwd/;
use File::Temp qw/tempdir/;

use warnings FATAL => qw/ io inplace /;
our $FE = $] ge '5.012' && $] lt '5.029007' ? !!0 : !!1; # FE="first eof", see http://rt.perl.org/Public/Bug/Display.html?id=133721
our $BE; # BE="buggy eof", Perl 5.14.x had several regressions regarding eof (and a few others) (gets set below)
our $CE; # CE="can't eof()", Perl <5.12 doesn't support eof() on tied filehandles (gets set below)
our $FL = undef; # FL="First Line"
# Apparently there are some versions of Perl on Win32 where the following two appear to work slightly differently.
# I've seen differing results on different systems and I'm not sure why, so I set it dynamically... not pretty, but this test isn't critical.
if ( $^O eq 'MSWin32' && $] ge '5.014' && $] lt '5.018' )
	{ $FL = $.; $FE = defined($.) }

BEGIN { use_ok('Tie::Handle::Argv') }

sub testboth {
	# test that both regular ARGV and our tied base class act the same
	die "bad nr of args" unless @_==2 || @_==3;
	my ($name, $sub, $args) = @_;
	my $stdin = delete $$args{stdin};
	{
		local (*ARGV, $.);
		my $osi = defined($stdin) ? OverrideStdin->new($stdin) : undef;
		subtest "$name - untied" => $sub;
		$osi and $osi->restore;
	}
	{
		local (*ARGV, $.);
		local $CE = $] lt '5.012';
		local $BE = $] ge '5.014' && $] lt '5.016';
		tie *ARGV, 'Tie::Handle::Argv';
		my $osi = defined($stdin) ? OverrideStdin->new($stdin) : undef;
		subtest "$name - tied" => $sub;
		$osi and $osi->restore;
		untie *ARGV;
	}
	return;
}

testboth 'restart with emptied @ARGV (STDIN)' => sub {
	plan $^O eq 'MSWin32' ? (skip_all => 'STDIN tests don\'t work yet on Windows') : (tests=>2);
	my @tf = (newtempfn("Fo\nBr"), newtempfn("Qz\nBz\n"));
	my @states;
	@ARGV = @tf;
	push @states, [[@ARGV], $ARGV, defined(fileno ARGV), $., eof];
	push @states, [[@ARGV], $ARGV, defined(fileno ARGV), $., eof, $_] while <>;
	push @states, [[@ARGV], $ARGV, defined(fileno ARGV), $., eof];
	SKIP: {
		skip "eof() not supported on tied handles on Perl<5.12", 1 if $CE;
		ok !eof(), 'eof() is false';
	}
	push @states, [[@ARGV], $ARGV, defined(fileno ARGV), $., eof];
	push @states, [[@ARGV], $ARGV, defined(fileno ARGV), $., eof, $_] while <>;
	push @states, [[@ARGV], $ARGV, defined(fileno ARGV), $., eof];
	is_deeply \@states, [
		[[@tf],    undef,  !!0, undef, $FE           ],
		[[$tf[1]], $tf[0], !!1, 1,     !!0, "Fo\n"   ],
		[[$tf[1]], $tf[0], !!1, 2,     !!1, "Br"     ],
		[[],       $tf[1], !!1, 3,     !!0, "Qz\n"   ],
		[[],       $tf[1], !!1, 4,     !!1, "Bz\n"   ],
		[[],       $tf[1], !!0, 4,     $BE?!!0:!!1   ],
		$CE ? [[], $tf[1], !!0, 4,     $BE?!!0:!!1   ]
		    : [[], '-',    !!1, 0,     !!0           ],
		[[],       '-',    !!1, 1,     !!0, "Hello\n"],
		[[],       '-',    !!1, 2,     !!1, "World"  ],
		[[],       '-',    !!0, 2,     $BE?!!0:!!1   ],
	], 'states' or diag explain \@states;
}, {stdin=>"Hello\nWorld"};

my @details = Test::More->builder->details;
for my $i (0..$#details) {
	diag "Passing TO"."DO Test #".($i+1).": ", explain($details[$i]{name})
		if $details[$i]{type} eq 'to'.'do' && $details[$i]{actual_ok};
}

done_testing;
