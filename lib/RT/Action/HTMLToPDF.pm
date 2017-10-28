package RT::Action::HTMLToPDF;


use utf8;
use MIME::Entity;
use File::Temp;
use Encode;

use base 'RT::Action';

use strict;
use warnings;

=head1 NAME

RT::Action::HTMLToPDF - Generate PDF from HTML and attach it to a ticket

=head1 DESCRIPTION

This action creates PDF document based on given HTML document and attaches it to
 a ticket. HTML retrieved from RT template selected in Scrip.

=cut


=head1 VARIABLES

=cut


=head2 @template_headers

List of available template headers

=cut

my @template_headers = qw/X-Filename-Prefix X-Message-Contents X-Message-Type/;


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
        RT::Logger->error('[RT::Extension::HTMLToPDF]: Incomplete config in SiteConfig, see README');
        return 0;
    }
    unless ($self->TemplateObj) {
        RT::Logger->error('[RT::Extension::HTMLToPDF]: No template passed. Abort.');
        return 0;
    }
    $self->TemplateObj->Parse(
        TicketObj => $self->TicketObj,
        TransactionObj => $self->TransactionObj
    );

    # Retrieve template headers without "\n". Empty string if not found
    my %headers = ();
    @headers{@template_headers} = map{ s/[\n\r]$//gr } map { $self->TemplateObj->MIMEObj->head->get($_) || '' } @template_headers; #/

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
    my $date = `date +"%d-%m-%Y_%H:%M"`;
    chomp $date;
    my $fn_prefix = $tpl_headers->{'X-Filename-Prefix'};
    my $fn = $fn_prefix . $date . '.pdf';

    # Retrieve our template parsed contents
    my $tpl_str = $self->TemplateObj->MIMEObj->bodyhandle->as_string;

    if ($config->{'PDFHTMLDebug'}) {
        RT::Logger->debug("[RT::Extension::HTMLToPDF]: HTML contents: $tpl_str");
    }

    my $pdf_fh = File::Temp->new(
        SUFFIX => '.pdf',
        UNLINK => 1
    );
    my $pdf_fn = $pdf_fh->filename;

    my @cmd = ('xvfb-run', 'wkhtmltopdf');
    push @cmd, grep{ defined } %{$config->{'PDFConvertCommandOptions'}};
    push @cmd, ('-', $pdf_fn);
    RT::Logger->info('[RT::Extension::HTMLToPDF]: Executing "' . join(' ', @cmd) . '"');

    my $pid = open(my $cmd_fh, '|-', @cmd);
    unless ($pid) {
        RT::Logger->error(
            "[RT::Extension::HTMLToPDF]: Error execute pdf convert command: $! [PATH=$ENV{PATH}]"
        );
        $self->record_error_txn();
        return 0;
    }
    print $cmd_fh $tpl_str;
    close $cmd_fh;

    # Build MIME object
    my $mime_obj = MIME::Entity->build(
        Type => "multipart/mixed",
        Charset => "UTF-8"
    );

    my $msg_contents = $tpl_headers->{'X-Message-Contents'};
    utf8::decode($msg_contents) unless utf8::is_utf8($msg_contents);
    $mime_obj->attach(
        Type => "text/plain",
        Charset => "UTF-8",
        Data => Encode::encode("UTF-8", $msg_contents)
    ) if ($msg_contents);

    $mime_obj->attach(
        Path => $pdf_fn,
        Type => 'application/pdf',
        Filename => $fn,
        Disposition => "attachment",
        # Data => $pdf_str
    );

    # Write message txn
    my $msg_type = lc $tpl_headers->{'X-Message-Type'} || 'comment';
    if ($msg_type !~ /comment|correspond/) {
        RT::Logger->warning("[RT::Extension::HTMLToPDF]: Invalid value '$msg_type' in X-Message-Type header. Comment will be written");
        $msg_type = 'comment';
    }
    my ($txnid, $err_msg, $txn);
    if ($msg_type eq 'correspond') {
        ($txnid, $err_msg, $txn) = $self->TicketObj->Correspond(
            MIMEObj => $mime_obj
        );
    } elsif ($msg_type eq 'comment') {
        ($txnid, $err_msg, $txn) = $self->TicketObj->Comment(
            MIMEObj => $mime_obj
        );
    }
    unless ($txnid) {
        RT::Logger->error("[RT::Extension::HTMLToPDF]: Unable to create $msg_type transaction: $err_msg");
        return 0;
    }
    
    my $tickid = $self->TicketObj->id;
    RT::Logger->info("[RT::Extension::HTMLToPDF]: Create PDF successful: $fn in txn #$txnid ticket #$tickid");

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
        $RT::Logger->warning("[RT::Extension::HTMLToPDF]: Could not record error transaction: $msg");
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
    );
    return (undef) if (scalar(grep { ! defined $_ } values %conf));
    return (undef) if (ref($conf{'PDFConvertCommandOptions'}) ne 'HASH');

    return \%conf;
}

1;