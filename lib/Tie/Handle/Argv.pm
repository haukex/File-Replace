#!perl
package Tie::Handle::Argv;
use warnings;
use strict;
use Carp;

# For AUTHOR, COPYRIGHT, AND LICENSE see the bottom of this file

our $VERSION = '0.16a';

sub TIEHANDLE {
	return {
		__innerhandle => \do{local*HANDLE;*HANDLE},
		__lineno => undef,  # also keeps state: undef = not currently active, defined = active
	};
}

sub FILENO { fileno shift->{__innerhandle} }

sub OPEN {
	my $self = shift;
	$self->CLOSE if defined $self->FILENO;
	return open $self->{__innerhandle}, shift, @_;
}

sub _close {
	my ($self, $keep_lineno) = shift;
	my $rv = close shift->{__innerhandle};
	$self->{__lineno} = 0 unless $keep_lineno;
	$. = $self->{__lineno};
	return $rv;
}
sub CLOSE { return shift->_close }

sub _advance {
	my ($self, $peek) = @_;
	if ( !defined($self->{__lineno}) && !@ARGV ) {  # file list is initially empty
		unshift @ARGV, '-';
		$. = 0;  # the normal <> also resets $. to 0 in this case
	}
	FILE: {
		$self->_close('keep_lineno') if defined $self->{__lineno};
		if ( !@ARGV ) { # file list is now empty, closing and done
			$self->{__lineno} = undef unless $peek;
			return;
		} # else
		$ARGV = shift @ARGV;
		# note: ->OPEN uses ->CLOSE (resets $.), but we don't want that, so we ->_close above
		if ( $self->OPEN($ARGV) )
			{ defined $self->{__lineno} or $self->{__lineno} = 0 }
		else { warn "Can't open $ARGV: $!"; redo FILE }
	}
	return 1;
}

sub READLINE {
	my $self = shift;
	my @out;
	RL_LINE: while (1) {
		while ($self->EOF(1)) {
			# current file is at EOF, advance
			$self->_advance or last RL_LINE;
		}
		my $line = scalar readline shift->{__innerhandle};
		last unless defined $line;
		push @out, $line;
		$. = ++$self->{__lineno};
		last unless wantarray;
	}
	return wantarray ? @out : $out[0];
}

sub EOF {
	my $self = shift;
	# "Starting with Perl 5.12, an additional integer parameter will be passed.
	# It will be zero if eof is called without parameter;
	# 1 if eof is given a filehandle as a parameter, e.g. eof(FH);
	# and 2 in the very special case that the tied filehandle is ARGV
	# and eof is called with an empty parameter list, e.g. eof()."
	if ( @_ && $_[0]==2 ) {
		while ( eof shift->{__innerhandle} ) {  # current file is at EOF, peek
			return !!1 unless $self->_advance("peek");  # could not peek => EOF
		}
		return !!0;  # not at EOF
	}
	return eof shift->{__innerhandle};
}

sub DESTROY {
	my $self = shift;
	delete @$self{ grep {/^__/} keys %$self };
}

1;
__END__

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

