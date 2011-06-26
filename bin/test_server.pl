#!/usr/bin/perl

use FindBin qw($Bin);
use lib "$Bin/../lib";

use NNTP::Portal::App;

NNTP::Portal::App->run;
