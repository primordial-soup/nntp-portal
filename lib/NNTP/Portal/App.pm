package NNTP::Portal::App;
use Bread::Board;

use NNTP::Portal::News::Server;

sub run {
	NNTP::Portal::News::Server->run;
}

1;

=head1 NAME

NNTP::Portal::App

=cut
