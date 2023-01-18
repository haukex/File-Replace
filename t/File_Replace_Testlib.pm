#!perl
package File_Replace_Testlib;
use warnings;
use strict;
use 5.008_001;
use Carp;

=head1 Synopsis

Test support library for the Perl module File::Replace.

=head1 Author, Copyright, and License

Copyright (c) 2017 Hauke Daempfling (haukex@zero-g.net)
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

use parent 'Exporter';
our @EXPORT = qw/ newtempfn /;

sub import {
	__PACKAGE__->export_to_level(1, @_);
	$File::Replace::DISABLE_CHMOD = 1 unless chmod(oct('640'), newtempfn(""));
	return;
}

use File::Temp qw/tempdir tempfile/;
# always returns a new temporary filename
# newtempfn() - return a nonexistent filename (small chance for a race condition)
# newtempfn("content") - writes that content to the file (file will exist)
# newtempfn("content","layers") - does binmode with those layers then writes the content
our $TEMPDIR = tempdir("FileReplaceTests_XXXXXXXXXX", TMPDIR=>1, CLEANUP=>1);
sub newtempfn {
	my ($fh,$fn) = tempfile(DIR=>$TEMPDIR,UNLINK=>1);
	if (@_) {
		my $content = shift;
		if (@_) {
			binmode $fh, shift or croak "binmode $fn: $!";
			@_ and carp "too many args to newtempfn";
		}
		print $fh $content or croak "print $fn: $!";
		close $fh or croak "close $fn: $!";
	}
	else {
		close $fh or croak "close $fn: $!";
		unlink $fn or croak "unlink $fn: $!";
	}
	return $fn;
}

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

1;
