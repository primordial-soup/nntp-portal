package NNTP::Portal::Config;

use MooseX::Singleton;
use Config::Merge;
use File::Spec;
use File::Path qw(make_path);
use File::HomeDir;

use constant CONFIG_DIR => ( '.nntp-portal', 'config' );
use constant DB_DIR     => ( '.nntp-portal', 'db' );
use constant LOG_DIR     => ( '.nntp-portal', 'log' );

has config_dir => (
	is => 'ro',
	isa => 'Str',
	default => sub {
		my $home = File::HomeDir->my_home;
		return File::Spec->catfile($home, CONFIG_DIR);
	}
);

has config => (
	is => 'ro',
	isa => 'Config::Merge',
	lazy => 1,
	default => sub {
		my $self = shift;
		my $config = $self->config_dir;
		make_path($config);
		return Config::Merge->new($config);
	}
);

has plugin_dir => (
	is => 'ro',
	isa => 'Str',
	lazy => 1,
	default => sub {
		my $self = shift;
		my $config = $self->config_dir;
		return File::Spec->catfile($config, 'plugin');
	}
);

# TODO: this is temporary until a proper configuration is added
has db_dir => (
	is => 'ro',
	isa => 'Str',
	lazy => 1,
	default => sub {
		my $self = shift;
		my $home = File::HomeDir->my_home;
		my $db_dir = File::Spec->catfile($home, DB_DIR);
		make_path($db_dir);
		return $db_dir;
	}
);

# TODO: this is temporary until a proper configuration is added
has log_dir => (
	is => 'ro',
	isa => 'Str',
	lazy => 1,
	default => sub {
		my $self = shift;
		my $home = File::HomeDir->my_home;
		my $log_dir = File::Spec->catfile($home, LOG_DIR);
		make_path($log_dir);
		return $log_dir;
	}
);

sub make_plugin_dir {
	my $self = shift;
	make_path($self->plugin_dir);
}

no Moose;
__PACKAGE__->meta->make_immutable;

=head1 NAME

NNTP::Portal::Config

=cut
