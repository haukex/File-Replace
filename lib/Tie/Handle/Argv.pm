#!perl
package Tie::Handle::Argv;
use warnings;
use strict;
use Carp;

# For AUTHOR, COPYRIGHT, AND LICENSE see the bottom of this file

our $VERSION = '0.15';

my %TIEHANDLE_KNOWN_ARGS = map {($_=>1)} qw/ files filename /;

sub TIEHANDLE {  ## no critic (RequireArgUnpacking)
	my $class = shift;
	croak $class."::tie/new: bad number of arguments" if @_%2;
	my %args = @_;
	for (keys %args) { croak "$class->tie/new: unknown argument '$_'"
		unless $TIEHANDLE_KNOWN_ARGS{$_} }
	croak "$class->tie/new: filename must be a scalar ref"
		if defined($args{filename}) && ref $args{filename} ne 'SCALAR';
	croak "$class->tie/new: files must be an arrayref"
		if defined($args{files}) && ref $args{files} ne 'ARRAY';
	my $self = { __innerhandle=>\do{local*HANDLE;*HANDLE} };
	$self->{__lineno} = undef; # also keeps state: undef = not currently active, defined = active
	$self->{__s_argv} = $args{filename};
	$self->{__a_argv} = $args{files};
	return $self;
}

sub OPEN {
	my $self = shift;
	$self->CLOSE if defined $self->FILENO;
	if (@_) { return open $self->{__innerhandle}, shift, @_ }
	else    { return open $self->{__innerhandle} }
}

sub inner_close {
	close shift->{__innerhandle}
}
sub _close {
	my $self = shift;
	confess "bad number of arguments to _close" unless @_==1;
	my $keep_lineno = shift;
	my $rv = $self->inner_close;
	if ($keep_lineno)
		{ $. = $self->{__lineno} }  ## no critic (RequireLocalizedPunctuationVars)
	else
		{ $. = $self->{__lineno} = 0 }  ## no critic (RequireLocalizedPunctuationVars)
	return $rv;
}
sub CLOSE { return shift->_close(0) }

sub init_empty_argv {
	my $self = shift;
	unshift @{ defined $self->{__a_argv} ? $self->{__a_argv} : \@ARGV }, '-';
	return;
}
sub advance_argv {
	my $self = shift;
	# Note: we do these gymnastics with the references because we always want
	# to access the currently global $ARGV and @ARGV - if we just stored references
	# to these in our object, we wouldn't notices changes due to "local"ization!
	return ${ defined $self->{__s_argv} ? $self->{__s_argv} : \$ARGV }
		= shift @{ defined $self->{__a_argv} ? $self->{__a_argv} : \@ARGV };
}
sub sequence_end {}
sub _advance {
	my $self = shift;
	my $peek = shift;
	confess "too many arguments to _advance" if @_;
	if ( !defined($self->{__lineno}) && !@{ defined $self->{__a_argv} ? $self->{__a_argv} : \@ARGV } ) {
		# file list is initially empty ($.=0)
		# the normal <> also appears to reset $. to 0 in this case:
		$. = 0;  ## no critic (RequireLocalizedPunctuationVars)
		$self->init_empty_argv;
	}
	FILE: {
		$self->_close(1) if defined $self->{__lineno};
		if ( !@{ defined $self->{__a_argv} ? $self->{__a_argv} : \@ARGV } ) {
			# file list is now empty, closing and done ($.=$.)
			$self->{__lineno} = undef unless $peek;
			$self->sequence_end;
			return;
		} # else
		my $fn = $self->advance_argv;
		# note: ->OPEN uses ->CLOSE, but we don't want that, so we ->_close above
		if ( $self->OPEN($fn) ) {
			defined $self->{__lineno} or $self->{__lineno} = 0;
		}
		else {
			warnings::warnif("inplace", "Can't open $fn: $!");
			redo FILE;
		}
	}
	return 1;
}

sub read_one_line {
	return scalar readline shift->{__innerhandle};
}
sub READLINE {
	my $self = shift;
	my @out;
	RL_LINE: while (1) {
		while ($self->EOF(1)) {
			# current file is at EOF, advancing
			$self->_advance or last RL_LINE;
		}
		my $line = $self->read_one_line;
		last unless defined $line;
		push @out, $line;
		$. = ++$self->{__lineno};  ## no critic (RequireLocalizedPunctuationVars)
		last unless wantarray;
	}
	return wantarray ? @out : $out[0];
}

sub inner_eof {
	eof shift->{__innerhandle}
}
sub EOF {  ## no critic (RequireArgUnpacking)
	my $self = shift;
	# "Starting with Perl 5.12, an additional integer parameter will be passed.
	# It will be zero if eof is called without parameter;
	# 1 if eof is given a filehandle as a parameter, e.g. eof(FH);
	# and 2 in the very special case that the tied filehandle is ARGV
	# and eof is called with an empty parameter list, e.g. eof()."
	if (@_ && $_[0]==2) {
		while ( $self->inner_eof(1) ) {  # current file is at EOF, peek
			if ( not $self->_advance("peek") ) { # could not peek => EOF
				return !!1;
			}
		}
		return !!0; # Not at EOF
	}
	return $self->inner_eof(@_);
}

sub BINMODE  {
	my $fh = shift->{__innerhandle};
	if (@_) { return binmode($fh,$_[0]) }
	else    { return binmode($fh)       }
}
sub READ     { read($_[0]->{__innerhandle}, $_[1], $_[2], defined $_[3] ? $_[3] : 0 ) }
sub FILENO   {   fileno  shift->{__innerhandle} }
sub GETC     {     getc  shift->{__innerhandle} }
sub SEEK     {     seek  shift->{__innerhandle}, $_[0], $_[1] }
sub TELL     {     tell  shift->{__innerhandle} }

sub UNTIE {
	my $self = shift;
	delete @$self{ grep {/^__/} keys %$self };
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

