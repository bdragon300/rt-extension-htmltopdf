# Summary

RT::Extension::HTMLToPDF - Generate PDF using HTML from RT template


# Description

The extension takes HTML from Template and generates PDF using wkhtmltopdf 
tool. Generated document attaches to a ticket.


# Dependencies

* RT >= 4.0.0
* MIME::Entity
* wkhtmltopdf, xvfb tools


# Installation

1. Firstly, install wkhtmltopdf, xvfb utilities:

	* On Debian: `apt-get install wkhtmltopdf xvfb`

	* On Centos, RedHat: `yum install wkhtmltox xorg-x11-server-Xvfb`

	**NOTE:** probably you will need to install additional font packages.

2. Next, do following (May need root permissions):

	`$ perl Makefile.PL && make && make install`

3. Then, insert extension data into RT database:

	`$ make initdb`

	Be careful, run the last command one time only, otherwise you can get duplicates
	in the database.

4. Finally, let RT to get to know about the extension. Write in *RT_SiteConfig.pm* following:

	For RT>=4.2:

	```
	Plugin( "RT::Extension::HTMLToPDF" );
	```

	For RT<4.2:

	```
	Set(@Plugins, qw(RT::Extension::HTMLToPDF));
	```

	After installing you may need to restart webserver.


# Quick example

```
X-Filename-Prefix: Invoice_

<html><body>
<h1>Hello!</h1>
<p>Hello, I'm the ticket #{$Ticket->id}!</p>
</body></html>
```


# Template headers

HTML templates can contain some config headers.

### X-Filename-Prefix

Optional. Specifies the PDF file name prefix. Normally, generated file will be 
named with current datetime, but it can have prefix.

Default is empty prefix.

```
X-Filename-Prefix: Invoice_
```

In this example the file will be named as "Invoice_22-06-2017 17:41.pdf".


# Configuration

The extension has some configuration options in RT_SiteConfig.pm.

### $PDFConvertCommandOptions

Optional. Which options will be passed to a wkhtmltopdf command. See wkhtmltopdf 
manpage for options list.

Default is no options.

```
Set($PDFConvertCommandOptions, {
        '--encoding' => 'utf-8',
        '--zoom' => '1.1',
        '--margin-top' => '4',
        '--no-images' => undef, # Used as flag
        '-n' => undef           # Used as flag
    });
```

### $PDFConvertCommand

Optional. During convert this command will be executed.

Default is shown below.

```
Set($PDFConvertCommand, 'xvfb-run wkhtmltopdf');
```

### $PDFCommentMsg

Optional. Message of comment to which a PDF file will be linked as attachment.

Default is empty message.

```
Set($PDFCommentMsg, 'Comment message');
```

### $PDFHTMLDebug

Optional. Print a retrieved HTML to the debug log.

Default is 0.

```
Set($PDFHTMLDebug, 1);
```


# Author

Igor Derkach, <gosha753951@gmail.com>


# Bugs

Please report any bugs or feature requests to the author.


# Copyright and license

Copyright 2017 Igor Derkach, <https://github.com/bdragon300/>

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

Request Tracker (RT) is Copyright Best Practical Solutions, LLC.
