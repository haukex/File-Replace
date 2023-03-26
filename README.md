Tie-Handle-Base
===============

This is the distribution of the Perl module
[`Tie::Handle::Base`](https://metacpan.org/pod/Tie::Handle::Base).

It is a Perl extension that provides a more complete base class
for tied filehandles than the core module `Tie::StdHandle`.

Please see the module's documentation (POD) for details (try the command
`perldoc lib/Tie/Handle/Base.pm`) and the file `Changes` for version
information.

[![Kwalitee Score](https://cpants.cpanauthors.org/dist/Tie-Handle-Base.svg)](https://cpants.cpanauthors.org/dist/Tie-Handle-Base)
[![CPAN Testers](https://badges.zero-g.net/cpantesters/Tie-Handle-Base.svg)](http://matrix.cpantesters.org/?dist=Tie-Handle-Base)

Important Note About the Repository
-----------------------------------

Because this module's code was forked from the original File-Replace
distribution and repository, its code is still contained in the
`File-Replace` repository, **branch `tiehandle`**, which you can find
at **<https://github.com/haukex/File-Replace/tree/tiehandle>**.

If you're checking out this suite of modules from Git, I suggest the following:

	git clone --branch tiehandle https://github.com/haukex/File-Replace.git Tie-Handle-Base
	git clone --branch onlyreplace https://github.com/haukex/File-Replace.git File-Replace
	git clone --branch fancyreplace https://github.com/haukex/File-Replace.git File-Replace-Fancy
	git clone --branch reinplace https://github.com/haukex/File-Replace.git File-Replace-Inplace

Installation
------------

To install this module type the following:

	perl Makefile.PL
	make
	make test
	make install

If you are running Windows, you may need to use `dmake`, `nmake`, or `gmake`
instead of `make`.

Dependencies
------------

Requirements: Perl v5.8.1 or higher (a more current version is *strongly*
recommended) and several of its core modules; users of older Perls may need
to upgrade some core modules.

The full list of required modules can be found in the file `Makefile.PL`.
This module should work on any platform supported by these modules.

Author, Copyright and License
-----------------------------

Copyright (c) 2017-2023 Hauke Daempfling <haukex@zero-g.net>
at the Leibniz Institute of Freshwater Ecology and Inland Fisheries (IGB),
Berlin, Germany, <http://www.igb-berlin.de/>

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <http://www.gnu.org/licenses/>.

