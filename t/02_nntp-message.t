#!/usr/bin/perl

use Test::More;

BEGIN { use_ok( 'NNTP::Message' ); }
require_ok( 'NNTP::Message' );

my @lines; push @lines, $_ while(<DATA>);
my $text = join '', @lines;
#diag "$text";

my $msg = NNTP::Message->read( $text );

ok( defined $msg, 'read()');
isa_ok( $msg, 'NNTP::Message', 'correct type');

is_deeply( $msg->get_newsgroups, [ 'comp.lang.c', 'comp.lang.perl' ], 'get_newsgroups');

is( $msg->get_subject, 'The subject', 'subject field');
is( $msg->get_from, 'me <me@example.com>', 'from field');

is_deeply( $msg->get_xref, { 'comp.lang.c' => 400, 'comp.lang.perl' => 80 }, 'xref');

is($msg->get_references, '<hash@example.com> <other@example.org>', 'references');

is( $msg->get_datetime->epoch, 5, 'Unix time');

is( $msg->get_messageID, '<80A8209user@example.com>', 'message ID');

my $new_msg = $msg->clone;

ok( defined $new_msg, 'clone()');
isa_ok( $new_msg, 'NNTP::Message', 'correct type');

is( $new_msg->get_messageID, '<80A8209user@example.com>', 'message ID');

$new_msg->strip_xref;

is_deeply( $new_msg->get_xref, {}, 'xref after stripped');

my $new_xref = { 'comp.lang.c' => 401, 'comp.lang.perl' => 81 };
my $new_servername = 'test';
$new_msg->set_xref($new_servername, $new_xref );

is_deeply( $new_msg->get_xref, $new_xref, 'xref added');

like( $new_msg->study('xref'), qr/^$new_servername/, 'xref servername' );

done_testing;

__DATA__
Subject: The subject
From: me <me@example.com>
Message-ID: <80A8209user@example.com>
Newsgroups: comp.lang.c,comp.lang.perl
Date: Thu, 01 Jan 1970 00:00:05 GMT
References: <hash@example.com>
	<other@example.org>
Xref: example.com comp.lang.c:400
	comp.lang.perl:80

Hello!
