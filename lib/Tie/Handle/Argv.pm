#!perl
package Tie::Handle::Argv;
use warnings;
use strict;
use Carp;
use warnings::register;

# For AUTHOR, COPYRIGHT, AND LICENSE see the bottom of this file

our $VERSION = '0.09';

require Tie::Handle::Base;
our @ISA = qw/ Tie::Handle::Base /;  ## no critic (ProhibitExplicitISA)

my %TIEHANDLE_KNOWN_ARGS = map {($_=>1)} qw/ debug /;

sub TIEHANDLE {  ## no critic (RequireArgUnpacking)
	my $class = shift;
	croak $class."::tie/new: bad number of arguments" if @_%2;
	my %args = @_;
	$TIEHANDLE_KNOWN_ARGS{$_} or croak $class."::tie/new: unknown argument '$_'"
		for keys %args;
	my $self = $class->SUPER::TIEHANDLE();
	$self->{_lineno} = undef; # also keeps state: undef = not currently active, defined = active
	$self->{_debug} = ref($args{debug}) ? $args{debug} : ( $args{debug} ? *STDERR{IO} : undef);
	return $self;
}

sub _debug {  ## no critic (RequireArgUnpacking)
	my $self = shift;
	return unless $self->{_debug};
	confess "not enough arguments to _debug" unless @_;
	print {$self->{_debug}} ref($self), " DEBUG: ", @_ ,"\n";
	return;
}

sub _close {
	my $self = shift;
	confess "bad number of arguments to _close" unless @_==1;
	my $keep_lineno = shift;
	my $rv = $self->SUPER::CLOSE(@_);
	if ($keep_lineno)
		{ $. = $self->{_lineno} }  ## no critic (RequireLocalizedPunctuationVars)
	else
		{ $. = $self->{_lineno} = 0 }  ## no critic (RequireLocalizedPunctuationVars)
	return $rv; # see tests in 20_tie_handle_base.t: we know close always returns a scalar
}
sub CLOSE { return shift->_close(0) }

sub _advance {
	my $self = shift;
	my $peek = shift;
	confess "too many arguments to _advance" if @_;
	if ( !defined($self->{_lineno}) && !@ARGV ) {
		$self->_debug("\@ARGV is empty, adding '-' (\$.=0)");
		unshift @ARGV, '-';
		# the normal ARGV also appears to behave like this:
		$. = 0;  ## no critic (RequireLocalizedPunctuationVars)
	}
	FILE: {
		$self->_close(1) if defined $self->{_lineno};
		if (!@ARGV) {
			$self->_debug("\@ARGV is now empty, closing and done (\$.=$.)");
			$self->{_lineno} = undef unless $peek;
			return;
		} # else
		$ARGV = shift @ARGV;  ## no critic (RequireLocalizedPunctuationVars)
		$self->_debug("opening '$ARGV'");
		# note: ->SUPER::OPEN uses ->CLOSE, but we don't want that, so we ->_close above
		if ( $self->OPEN($ARGV) ) {
			defined $self->{_lineno} or $self->{_lineno} = 0;
		}
		else {
			$self->_debug("open '$ARGV' failed: $!");
			warnings::warnif("inplace", "Can't open $ARGV: $!");
			redo FILE;
		}
	}
	return 1;
}

sub READLINE {
	my $self = shift;
	$self->_debug("readline in ", wantarray?"list":"scalar", " context");
	my @out;
	RL_LINE: while (1) {
		while ($self->EOF(1)) {
			$self->_debug("current file is at EOF, advancing");
			$self->_advance or last RL_LINE;
		}
		my $line = $self->SUPER::READLINE(@_);
		last unless defined $line;
		push @out, $line;
		$. = ++$self->{_lineno};  ## no critic (RequireLocalizedPunctuationVars)
		last unless wantarray;
	}
	$self->_debug("readline: ",0+@out," lines (\$.=$.)");
	return wantarray ? @out : $out[0];
}

sub EOF {  ## no critic (RequireArgUnpacking)
	my $self = shift;
	# "Starting with Perl 5.12, an additional integer parameter will be passed.
	# It will be zero if eof is called without parameter;
	# 1 if eof is given a filehandle as a parameter, e.g. eof(FH);
	# and 2 in the very special case that the tied filehandle is ARGV
	# and eof is called with an empty parameter list, e.g. eof()."
	if (@_ && $_[0]==2) { #TODO: what about Perls <5.12 ?
		while ( $self->EOF(1) ) {
			$self->_debug("eof(): current file is at EOF, peeking");
			if ( not $self->_advance("peek") ) {
				$self->_debug("eof(): could not peek => EOF");
				return !!1;
			}
		}
		$self->_debug("eof(): => Not at EOF");
		return !!0;
	}
	return $self->SUPER::EOF(@_);
}

sub WRITE { croak ref(shift)." is read-only" }

sub UNTIE {
	my $self = shift;
	delete @$self{qw/_lineno _debug/};
	return $self->SUPER::UNTIE(@_);
}

sub DESTROY {
	my $self = shift;
	delete @$self{qw/_lineno _debug/};
	return $self->SUPER::DESTROY(@_);
}

1;
__END__

=head1 Name

Tie::Handle::Argv - A base class for tying ARGV

=head1 Synopsis

 TODO: Doc

=head1 Description

TODO: Doc

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

