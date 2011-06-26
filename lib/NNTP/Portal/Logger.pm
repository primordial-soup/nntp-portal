package NNTP::Portal::Logger;

use NNTP::Portal::Config;
use File::Spec;
use Log::Log4perl;

sub init {
	my $conf_dir = NNTP::Portal::Config->instance()->config_dir;
	Log::Log4perl::init_and_watch( File::Spec->catfile($conf_dir, 'logger'), 60 );
}

1;

=head1 NAME

NNTP::Portal::Logger - logging initialization

=cut
