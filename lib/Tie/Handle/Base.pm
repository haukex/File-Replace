#!perl
package Tie::Handle::Base;
use warnings;
use strict;
use Carp;
use warnings::register;
use Scalar::Util qw/blessed/;

# For AUTHOR, COPYRIGHT, AND LICENSE see the bottom of this file

our $VERSION = '0.15';

## no critic (RequireFinalReturn, RequireArgUnpacking)

sub new {
	my $class = shift;
	my $fh = \do{local*HANDLE;*HANDLE};  ## no critic (RequireInitializationForLocalVars)
	tie *$fh, $class, @_;
	return $fh;
}

sub TIEHANDLE {
	my $class = shift;
	my $innerhandle = shift;
	$innerhandle = \do{local*HANDLE;*HANDLE}  ## no critic (RequireInitializationForLocalVars)
		unless defined $innerhandle;
	@_ and warnings::warnif("too many arguments to $class->TIEHANDLE");
	return bless { __innerhandle=>$innerhandle }, $class;
}
sub UNTIE    { delete shift->{__innerhandle}; return }
sub DESTROY  { delete shift->{__innerhandle}; return }

sub innerhandle { shift->{__innerhandle} }
sub set_inner_handle { $_[0]->{__innerhandle} = $_[1] }

sub BINMODE  {
	my $fh = shift->{__innerhandle};
	if (@_) { return binmode($fh,$_[0]) }
	else    { return binmode($fh)       }
}
sub READ     { read($_[0]->{__innerhandle}, $_[1], $_[2], defined $_[3] ? $_[3] : 0 ) }

sub CLOSE    {    close  shift->{__innerhandle} }
sub EOF      {      eof  shift->{__innerhandle} }
sub FILENO   {   fileno  shift->{__innerhandle} }
sub GETC     {     getc  shift->{__innerhandle} }
sub READLINE { readline  shift->{__innerhandle} }
sub SEEK     {     seek  shift->{__innerhandle}, $_[0], $_[1] }
sub TELL     {     tell  shift->{__innerhandle} }

sub OPEN {
	my $self = shift;
	$self->CLOSE if defined $self->FILENO;
	if (@_) { return open $self->{__innerhandle}, shift, @_ }
	else    { return open $self->{__innerhandle} }
}

sub PRINT {
	my $self = shift;
	my $str = join defined $, ? $, : '', @_;
	$str .= $\ if defined $\;
	return defined( $self->WRITE($str) ) ? 1 : undef;
}
sub PRINTF {
	my $self = shift;
	return defined( $self->WRITE(sprintf shift, @_) ) ? 1 : undef;
}

1;
__END__

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

