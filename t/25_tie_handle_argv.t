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

use Carp;
use File::Temp qw/tempfile/;

{
	package OverrideStdin;
	# This overrides STDIN with a file, using the same code that
	# IPC::Run3 uses, which seems to work well. Cleanup is performed
	# on object destruction.
	use Carp;
	use File::Temp qw/tempfile/;
	use POSIX qw/dup dup2/;
	our $DEBUG;
	BEGIN { $DEBUG = 0 }
	sub new {
		my $class = shift;
		croak "$class->new: bad nr of args" unless @_==1;
		my $string = shift;
		my $fh = tempfile();
		print $fh $string;
		seek $fh, 0, 0 or die "seek: $!";
		$DEBUG and print STDERR "Overriding STDIN\n";
		my $saved_fd0 = dup( 0 ) or die "dup(0): $!";
		dup2( fileno $fh, 0 ) or die "save dup2: $!";
		return bless \$saved_fd0, $class;
	}
	sub restore {
		my $self = shift;
		my $saved_fd0 = $$self;
		return unless defined $saved_fd0;
		$DEBUG and print STDERR "Restoring STDIN\n";
		dup2( $saved_fd0, 0 ) or die "restore dup2: $!";
		POSIX::close( $saved_fd0 ) or die "close saved: $!";
		$$self = undef;
		return 1;
	}
	sub DESTROY { return shift->restore }
}


sub newtempfn {
	my $content = shift;
	my ($fh,$fn) = tempfile(UNLINK=>1);
	print $fh $content or croak "print $fn: $!";
	close $fh or croak "close $fn: $!";
	return $fn;
}

use Test::More;

use warnings FATAL => qw/ io inplace /;
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
		tie *ARGV, 'Tie::Handle::Argv';
		my $osi = defined($stdin) ? OverrideStdin->new($stdin) : undef;
		subtest "$name - tied" => $sub;
		$osi and $osi->restore;
		untie *ARGV;
	}
}

testboth 'restart with emptied @ARGV (STDIN)' => sub { plan tests=>2;
	my @tf = (newtempfn("Fo\nBr"), newtempfn("Qz\nBz\n"));
	my @states;
	@ARGV = @tf;
	push @states, [[@ARGV], $ARGV, defined(fileno ARGV), $., eof];
	push @states, [[@ARGV], $ARGV, defined(fileno ARGV), $., eof, $_] while <>;
	push @states, [[@ARGV], $ARGV, defined(fileno ARGV), $., eof];
	ok !eof(), 'eof() is false';
	push @states, [[@ARGV], $ARGV, defined(fileno ARGV), $., eof];
	push @states, [[@ARGV], $ARGV, defined(fileno ARGV), $., eof, $_] while <>;
	push @states, [[@ARGV], $ARGV, defined(fileno ARGV), $., eof];
	is_deeply \@states, [
		[[@tf],    undef,  !!0, undef, !!1           ],
		[[$tf[1]], $tf[0], !!1, 1,     !!0, "Fo\n"   ],
		[[$tf[1]], $tf[0], !!1, 2,     !!1, "Br"     ],
		[[],       $tf[1], !!1, 3,     !!0, "Qz\n"   ],
		[[],       $tf[1], !!1, 4,     !!1, "Bz\n"   ],
		[[],       $tf[1], !!0, 4,     !!1           ],
		[[],       '-',    !!1, 0,     !!0           ],
		[[],       '-',    !!1, 1,     !!0, "Hello\n"],
		[[],       '-',    !!1, 2,     !!1, "World"  ],
		[[],       '-',    !!0, 2,     !!1           ],
	], 'states' or diag explain \@states;
}, {stdin=>"Hello\nWorld"};

done_testing;
