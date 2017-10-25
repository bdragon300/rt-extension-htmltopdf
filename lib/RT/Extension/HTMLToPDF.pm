package RT::Extension::HTMLToPDF;

use 5.010;
use strict;
use warnings;

our $VERSION = '0.1';


=head1 NAME

RT::Extension::HTMLToPDF - Generate PDF using HTML from RT template

=head1 DESCRIPTION

The extension takes HTML from Template and generates PDF using wkhtmltopdf 
tool. Generated document attaches to a ticket.

=head1 DEPENDENCIES

=over

=item RT E<gt>= 4.0.0

=item MIME::Entity

=item wkhtmltopdf, xvfb tools

=back

=head1 INSTALLATION

Firstly, install wkhtmltopdf, xvfb utilities.

=over

=item On Debian: C<apt-get install wkhtmltopdf xvfb>

=item On Centos, RedHat: C<yum install wkhtmltox xorg-x11-server-Xvfb>

=back

NOTE: probably you will need to install additional font packages.

Next, do following:

=over

=item C<perl Makefile.PL>

=item C<make>

=item C<make install>

May need root permissions

=item C<make initdb>

Be careful, run the last command one time only, otherwise you can get duplicates
in the database.

=back

=head1 CONFIGURATION

See README.md

=head1 AUTHOR

Igor Derkach E<lt>gosha753951@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2017 Igor Derkach, E<lt>https://github.com/bdragon300/E<gt>

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

Request Tracker (RT) is Copyright Best Practical Solutions, LLC.

=head1 METHODS

=cut

1;
