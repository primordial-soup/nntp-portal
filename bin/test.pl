#!/usr/bin/env perl

use FindBin qw($Bin);
use lib "$Bin/../lib";

use NNTP::Portal::TestPlugin;

NNTP::Portal::TestPlugin->new(
	plugin => 'NNTP::Portal::Plugin::Facebook'
)->run();
