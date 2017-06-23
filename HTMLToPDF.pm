package RT::Action::HTMLToPDF;


use utf8;
use MIME::Entity;
use File::Temp;
use Encode;

use base 'RT::Action';

use strict;
use warnings;

=head1 NAME

RT::Action::HTMLToPDF - Convert HTML to PDF based on standard RT template.

=head1 DESCRIPTION

This action creates PDF document based on given HTML document and attaches it to
 the ticket as comment. HTML retrieved from RT template selected in Scrip

Generated file name will contain optional prefix concatenated with current 
datetime. You can set prefix in template header X-Filename-Prefix, e.g. 
X-Filename-Prefix: Invoice_. If header has omitted then no prefix will be used.

=cut

=head1 INSTALLATION

Dependencies:

=over

=item * wkhtmltopdf

=item * xvfb

=back

Install dependencies. In Debian you can do:

C<apt-get install wkhtmltopdf xvfb>

Then copy this Action to RT's Action directory, usually 'lib/RT/Action'. Then
inform RT about this Action:
    
C<INSERT INTO scripactions (
    name, description, execmodule, creator, created, lastupdatedby, lastupdated) 
    VALUES ('HTMLToPDF', 'Convert HTML to PDF based on standard RT template.', 
    'HTMLToPDF', 1, now(), 1, now());>

=head1 CONFIGURATION

    # See wkhtmltopdf manpage for options list
    Set($PDFConvertCommandOptions, { # Optional. Default is no options
        '--encoding' => 'utf-8',
        '--zoom' => '1.1',
        '--margin-top' => '4',
        '--no-images' => undef, # Used as flag
        '-n' => undef           # Used as flag
    });
    Set($PDFConvertCommand, 'xvfb-run wkhtmltopdf'); # Optional.Default is shown
    Set($PDFCommentMsg, 'Comment message');  # Optional.Default is empty message
    Set($PDFHTMLDebug, 1);  # Optional. Print generated template html to the 
      debug log. Default is 0.

=cut


=head1 TEMPLATE EXAMPLE

    X-Filename-Prefix: Invoice_

    <html><body>
    <h1>Hello!</h1>
    <p>Hello, from the ticket #{$Ticket->id}!</p>
    </body></html>

Above HTML will be converted to file with name 'Invoice_22-06-2017 17:41.pdf'
and comment will be written with such file as attachment.


=head1 VARIABLES

=cut


=head2 @template_headers

List of available template headers

=cut

my @template_headers = ('X-Filename-Prefix');


=head1 METHODS

=head2 Prepare

Calls by RT to Prepare the Action

=cut

sub Prepare
{
    my $self = shift;

    # Read config
    $self->{'config'} = $self->read_config;
    unless ($self->{'config'}) {
        RT::Logger->error('[RT::Action::HTMLToPDF]: Incomplete config in SiteConfig, see README');
        return 0;
    }
    unless ($self->TemplateObj) {
        RT::Logger->error('[RT::Action::HTMLToPDF]: No template passed. Abort.');
        return 0;
    }
    $self->TemplateObj->Parse(
        TicketObj => $self->TicketObj,
        TransactionObj => $self->TransactionObj
    );

    # Retrieve template headers without "\n"
    my %headers = ();
    @headers{@template_headers} = map{ s/\n$//gr } map { $self->TemplateObj->MIMEObj->head->get($_) || '' } @template_headers; #/

    $self->{'tpl_headers'} = \%headers;

    return 1;
}


=head2 Commit

Calls by RT to Commit the Action

=cut

sub Commit
{
    my $self = shift;
    my $config = $self->{'config'};
    my $tpl_headers = $self->{'tpl_headers'};
    $self->{'tpl_headers'} = $self->{'config'} = undef;

    # Filename pattern
    my $fn_prefix = $tpl_headers->{'X-Filename-Prefix'};
    my $fn = $fn_prefix . `date +"%d-%m-%Y_%H:%M"` . '.pdf';

    # Retrieve our template parsed contents
    my $tpl_str = $self->TemplateObj->MIMEObj->bodyhandle->as_string;

    if ($config->{'PDFHTMLDebug'}) {
        RT::Logger->debug("[RT::Action::HTMLToPDF]: HTML contents: $tpl_str");
    }

    my $pdf_fh = File::Temp->new(
        SUFFIX => '.pdf',
        UNLINK => 1
    );
    my $pdf_fn = $pdf_fh->filename;

    my @cmd = ('xvfb-run', 'wkhtmltopdf');
    push @cmd, grep{ defined } %{$config->{'PDFConvertCommandOptions'}};
    push @cmd, ('-', $pdf_fn);
    RT::Logger->info('[RT::Action::HTMLToPDF]: Executing "' . join(' ', @cmd) . '"');

    my $pid = open(my $cmd_fh, '|-', @cmd);
    unless ($pid) {
        RT::Logger->error(
            "[RT::Action::HTMLToPDF]: Error execute pdf convert command: $! [PATH=$ENV{PATH}]"
        );
        $self->record_error_txn();
        return 0;
    }
    print $cmd_fh $tpl_str;
    close $cmd_fh;

    # Build comment MIME object
    my $comment_obj = MIME::Entity->build(
        Type => "multipart/mixed",
        Charset => "UTF-8"
    );

    $comment_obj->attach(
        Type => "text/plain",
        Charset => "UTF-8",
        Data => Encode::encode("UTF-8", $config->{'PDFCommentMsg'})
    ) if ($config->{'PDFCommentMsg'});

    $comment_obj->attach(
        Path => $pdf_fn,
        Type => 'application/pdf',
        Filename => $fn,
        Disposition => "attachment",
        # Data => $pdf_str
    );

    my ($txnid, $msg, $txn) = $self->TicketObj->Comment(MIMEObj => $comment_obj);
    unless ($txnid) {
        RT::Logger->error("[RT::Action::HTMLToPDF]: Unable to create Comment transaction: $msg");
        return 0;
    }
    RT::Logger->info("[RT::Action::HTMLToPDF]: Create PDF successful: $fn in txn #$txnid");

    return 1;
}


=head2 record_error_txn

Records error transaction to the ticket;

Receives 

None

Returns 

=over

=item int - just created transaction id

=item false - on error

=back

=cut
sub record_error_txn {
    my $self = shift;

    my $transaction
        = RT::Transaction->new( RT->SystemUser );

    my $type = 'SystemError';

    my ( $id, $msg ) = $transaction->Create(
        Ticket         => $self->TicketObj->Id,
        Type           => $type,
        Data           => 'Create PDF has failed. Please contact your admin, they can find more details in the logs.',
        ActivateScrips => 0
    );

    unless ($id) {
        $RT::Logger->warning("[RT::Action::HTMLToPDF]: Could not record error transaction: $msg");
    }
    return $id;
}


=head2 read_config

Read and validate configuration from RT_SiteConfig.pm

Returns 

Returns 

=over

=item HASHREF with config variables VarName=>Value 

=item undef when error

=back

=cut

sub read_config
{
    my %conf = (
        'PDFConvertCommand' => RT->Config->Get('PDFConvertCommand') // 'xvfb-run wkhtmltopdf',
        'PDFConvertCommandOptions' => RT->Config->Get('PDFConvertCommandOptions') // {},
        'PDFHTMLDebug' => RT->Config->Get('PDFHTMLDebug') // 0,
        'PDFCommentMsg' => RT->Config->Get('PDFCommentMsg') // '',
    );
    return (undef) if (scalar(grep { ! defined $_ } values %conf));
    return (undef) if (ref($conf{'PDFConvertCommandOptions'}) ne 'HASH');

    return \%conf;
}

1;