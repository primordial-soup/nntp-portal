package NNTP::Portal::News::Server;

=head1 NAME

NNTP::Portal::News::Server

=head1 DESCRIPTION

Uses L<POE::Component::Server::NNTP>

=cut

use strict;
use 5.010;
use POE qw(Component::Server::NNTP);

use NNTP::Portal::Config;
use NNTP::Portal::Logger;

use NNTP::Portal::News::Database::SQLite;
use File::Spec;
use DateTime::Format::Strptime;

# Load plugins
my @plugins = qw/ NNTP::Portal::Plugin::Facebook /;
#my @plugins = ();

my $update_interval = 30*60; # 30 minutes

use Data::Dumper;
#sub POE::Session::ASSERT_STATES () { 1 }	# TODO: debugging

my %plugin_instances;

=head2 Methods

=over 12

=cut

=item c<run()>

Starts the NNTP server

=cut
sub run {
	my $nntpd = POE::Component::Server::NNTP->spawn( 
			alias   => 'nntpd', 
			posting => 1, 
			port    => 10119,
			extra_cmds => [ qw/ capabilities / ] # must be lowercase
	);

	NNTP::Portal::Logger->init();

	my $dbfile = File::Spec->catfile(NNTP::Portal::Config->instance()->db_dir, 'nntp_portal.db');
	my $db = NNTP::Portal::News::Database::SQLite->new( dbi_dsn => "dbi:SQLite:dbname=$dbfile" );
	$db->init;
	for my $plugin (@plugins) {
		Class::MOP::load_class( $plugin );
		my $instance = $plugin->new( db => $db );
		$plugin_instances{$plugin} = $instance;
		eval {
			$instance->init();
			$instance->get_newsgroups();
		};
		if($@) {
			server_logger->error("Error initializing $plugin: $@");
		}
	}

	POE::Session->create(
		package_states => [
			'NNTP::Portal::News::Server' => [ qw(
					_start
					nntpd_connection
					nntpd_disconnected

					nntpd_cmd_post
					nntpd_cmd_ihave

					nntpd_cmd_newnews
					nntpd_cmd_newgroups
					nntpd_cmd_list
					nntpd_cmd_group

					nntpd_cmd_article
					nntpd_cmd_head
					nntpd_cmd_body

					nntp_cmd_capabilities
			) ],
		],
		inline_states => {
			plugin_update => sub {
				server_logger()->info("Updating plugins at ", time);
				for my $plugin (keys %plugin_instances) {
					server_logger()->info("Plugin ", $plugin, " @ ", time);
					eval {
						$plugin_instances{$plugin}->get_messages();
					};
					if($@) {
						server_logger()->error("Error getting messages from $plugin: $@");
					}
				}
				# TODO: temporary continuous update every $update_interval
				$_[KERNEL]->delay( plugin_update => $update_interval );
			}
		},
		options => { trace => 0 },
		args =>  [ $db ],
	);

	$poe_kernel->run();
	$db->end;
	exit 0;
}

sub server_logger {
	Log::Log4perl::get_logger( __PACKAGE__ );
}

sub recv_logger {
	Log::Log4perl::get_logger( __PACKAGE__."::recv" );
}

sub send_logger {
	Log::Log4perl::get_logger( __PACKAGE__."::send" );
}

sub _start {
	my ($kernel,$heap) = @_[KERNEL,HEAP];
	my $db = $_[ARG0];
	$heap->{clients} = { };
	$heap->{db} = $db;

	# TODO: this is temporary, need to write code to the RFC's date time spec
	my $date_parser = new DateTime::Format::Strptime(
		pattern     => '%Y%m%d %H%M%S',
		time_zone => '0',
	);
	$heap->{datetime} = $date_parser;

	$kernel->post( 'nntpd', 'register', 'all' );
	$kernel->yield( 'plugin_update' );
}

sub nntpd_connection {
	my ($kernel,$heap,$client_id) = @_[KERNEL,HEAP,ARG0];
	server_logger->debug("$client_id connected");
	$heap->{clients}->{ $client_id } = { };
	return;
}

sub nntpd_disconnected {
	my ($kernel,$heap,$client_id) = @_[KERNEL,HEAP,ARG0];
	server_logger->debug("$client_id disconnected");
	delete $heap->{clients}->{ $client_id };
	return;
}

# C<POST> TODO
# <url:find:rfc3977.txt#line=3093>
sub nntpd_cmd_post {
	my ($kernel,$sender,$client_id) = @_[KERNEL,SENDER,ARG0];
	recv_logger->debug("$client_id: POST");
	$kernel->post( $sender, 'send_to_client', $client_id, '440 posting not allowed' );
	return;
}

# C<IHAVE>
# <url:find:rfc3977.txt#line=3206>
# Not a transit server
sub nntpd_cmd_ihave {
	my ($kernel,$sender,$client_id) = @_[KERNEL,SENDER,ARG0];
	recv_logger->debug("$client_id: IHAVE");
	$kernel->post( $sender, 'send_to_client', $client_id, '435 article not wanted' );
	return;
}

# C<NEWNEWS> TODO
# <url:find:rfc3977.txt#line=3566>
#    Indicating capability: NEWNEWS
sub nntpd_cmd_newnews {
	my ($kernel,$sender,$client_id) = @_[KERNEL,SENDER,ARG0];
	recv_logger->debug("$client_id: NEWNEWS");
	$kernel->post( $sender, 'send_to_client', $client_id, '230 list of new articles follows' );
	$kernel->post( $sender, 'send_to_client', $client_id, '.' );
	return;
}

# C<NEWGROUPS>
# <url:find:rfc3977.txt#line=3493>
#    Indicating capability: READER
sub nntpd_cmd_newgroups {
	my ($kernel,$heap,$sender,$client_id, $date, $time, $gmt ) = @_[KERNEL,HEAP, SENDER,ARG0, ARG1, ARG2, ARG3 ];
	my $dt = $heap->{datetime}->parse_datetime("$date $time"); # TODO: ignoring $gmt for now
	my $newsgroups = $heap->{db}->get_new_newsgroups( $dt );
	$kernel->post( $sender, 'send_to_client', $client_id, '231 list of new newsgroups follows' );
	for my $ng (@$newsgroups) {
		my $hr = $heap->{db}->get_newsgroup_stats($ng);
		$kernel->post( $sender, 'send_to_client', $client_id,
			"$ng $hr->{high} $hr->{low} y" );
	}
	$kernel->post( $sender, 'send_to_client', $client_id, '.' );
	return;
}

# C<LIST> TODO
# <url:find:rfc3977.txt#line=3703>
#    Indicating capability: LIST
# C<LIST NEWSGROUPS>
#    needed for capability: READER
# <url:find:rfc3977.txt#line=4042>
# C<LIST ACTIVE>
#    needed for capability: READER
# <url:find:rfc3977.txt#line=3874>
sub nntpd_cmd_list {
	my ($kernel,$heap,$sender,$client_id) = @_[KERNEL,HEAP,SENDER,ARG0];
	
	$kernel->post( $sender, 'send_to_client', $client_id, '215 list of newsgroups follows' );
	if( $_[ARG1] eq "NEWSGROUPS" ) {
		# LIST NEWSGROUPS
		recv_logger->info("$client_id: LIST NEWSGROUPS");
		my $ngs = $heap->{db}->get_newsgroups;
		for my $ng (keys %$ngs) {
			$kernel->post( $sender, 'send_to_client', $client_id, "$ng $ngs->{$ng}" );
		}
	} elsif( $_[ARG1] eq "ACTIVE" ) {
		recv_logger->info("$client_id: LIST ACTIVE $_[ARG2]");
		# This should return only the ones the client is allowed to
		# select, so an aspect?
		my $newsgroups = $heap->{db}->get_newsgroups();
		for my $ng (@$newsgroups) {
			my $hr = $heap->{db}->get_newsgroup_stats($ng);
			$kernel->post( $sender, 'send_to_client', $client_id,
				"$ng $hr->{high} $hr->{low} y" );
		}
	} else {
		# LIST
		recv_logger->info("$client_id: LIST");
		my $ngs = $heap->{db}->get_newsgroups();
		foreach my $ng ( keys %$ngs ) {
			my $hr = $heap->{db}->get_newsgroup_stats($ng);
			$kernel->post( $sender, 'send_to_client', $client_id,
				"$ng $hr->{high} $hr->{low} y" );
		}
	}
	$kernel->post( $sender, 'send_to_client', $client_id, '.' );
	return;
}

# C<GROUP>
# <url:find:rfc3977.txt#line=1977>
sub nntpd_cmd_group {
	my ($kernel,$heap,$sender,$client_id,$group) = @_[KERNEL,HEAP,SENDER,ARG0,ARG1];
	recv_logger->info("$client_id: GROUP $group");

	my $ng_info = $heap->{db}->get_newsgroup_desc($group);
	unless ( defined $ng_info ) { 
		my $reply = '411 no such news group';
		send_logger->info("$client_id: $reply");
		$kernel->post( $sender, 'send_to_client', $client_id, $reply );
		return;
	}
	my $hr = $heap->{db}->get_newsgroup_stats($group);

	$heap->{clients}->{ $client_id }->{group} = $group;
	$heap->{clients}->{ $client_id }->{current_article} = $hr->{low};
		# set to first article or 0 (invalid)

	my $reply = "211 $hr->{count} $hr->{low} $hr->{high} $group selected";
	send_logger->info("$client_id: $reply");
	$kernel->post( $sender, 'send_to_client', $client_id, $reply );
		
	return;
}

# C<ARTICLE> TODO
# <url:find:rfc3977.txt#line=2527>
sub nntpd_cmd_article {
	my ($kernel,$heap,$sender,$client_id,$article) = @_[KERNEL,HEAP,SENDER,ARG0,ARG1];
	recv_logger->info("$client_id: ARTICLE $article");
	nntp_cmd_article_helper( $kernel, $heap, $sender, $client_id, $article, "ARTICLE" );
	return;
}

# C<HEAD> TODO
# <url:find:rfc3977.txt#line=2710>
sub nntpd_cmd_head {
	my ($kernel,$heap,$sender,$client_id,$article) = @_[KERNEL,HEAP,SENDER,ARG0,ARG1];
	recv_logger->info("$client_id: HEAD $article");
	nntp_cmd_article_helper( $kernel, $heap, $sender, $client_id, $article, "HEAD" );
	return;
}

# C<BODY> TODO
# <url:find:rfc3977.txt#line=2830>
sub nntpd_cmd_body {
	my ($kernel,$heap,$sender,$client_id,$article) = @_[KERNEL,HEAP,SENDER,ARG0,ARG1];
	recv_logger->info("$client_id: BODY $article");
	nntp_cmd_article_helper( $kernel, $heap, $sender, $client_id, $article, "BODY" );
	return;
}

sub nntp_cmd_article_helper {
	my ($kernel,$heap,$sender,$client_id,$article, $part) = @_;
	my $group = $heap->{clients}->{ $client_id}->{group};

	my $msg;
	my $article_id;
	my $msgid;
	# rather complex logic due to the three different possible commands
	if( !$article ) {
		# use current article
		server_logger->debug("$client_id: using current article");
		if( !defined $group ) {
			# no current group
			$kernel->post( $sender, 'send_to_client', $client_id, '412 no newsgroup selected' );
			return;
		}
		if( $heap->{clients}->{ $client_id }->{current_article} == 0 ) {
			my $reply = '420 Current article number is invalid';
			send_logger->info( "$client_id: $reply" );
			$kernel->post( $sender, 'send_to_client', $client_id,  );
			return;
		}
		$article_id = $heap->{clients}->{ $client_id }->{current_article};
		$msgid = $heap->{db}->get_msgid( $group, $article_id );
		if( defined $msgid ) {
			$msg = $heap->{db}->get_message( $msgid );
		} else {
			my $reply = '420 Current article number is invalid';
			send_logger->info("$client_id: $reply");
			$kernel->post( $sender, 'send_to_client', $client_id,  );
			return;
		}
	} elsif ( $article =~ /^<.*>$/ ) {
		# use message-id
		server_logger->debug("$client_id: using message-id");
		$msgid = $article;
		$msg = $heap->{db}->get_message( $msgid );
		if( defined $msg ) {
			if( defined $group ) {
				$article_id = $msg->get_xref()->{$group} // 0;
			}  else {
				$article_id = 0;
			}
		} else {
			my $reply = '430 No article with that message-id';
			send_logger->info("$client_id: $reply");
			$kernel->post( $sender, 'send_to_client', $client_id, $reply );
			return;
		}
	} elsif ( $article =~ /^\d+$/ ) {
		# use article number for current group
		server_logger->debug("$client_id: using article number for current group");
		$article_id = $article;
		if( !defined $group ) {
			# no current group
			my $reply = '412 no newsgroup selected';
			send_logger->info("$client_id: $reply");
			$kernel->post( $sender, 'send_to_client', $client_id, $reply );
			return;
		}
		$msgid = $heap->{db}->get_msgid( $group, $article_id );
		if( defined $msgid ) {
			$msg = $heap->{db}->get_message( $msgid );
		} else {
			my $reply = '423 no such article number';
			send_logger->info("$client_id: $reply");
			$kernel->post( $sender, 'send_to_client', $client_id, $reply );
			return;
		}
	} else {
		server_logger->error("$client_id: Invalid request for article $article");
		return;
	}
	server_logger->debug("$client_id:: group => $group, article_id => $article_id, message-id => $msgid");
	# TODO : remember that lines that begin with a period (.) need to have
	# a doubled-period sequence (..) to escape it (need to check if send_to_client does this)
	given( $part ) {
		when("ARTICLE") {
			my $msg_str = $msg->head . $msg->body->decoded;
			my $reply = "220 $article_id $msgid article retrieved - ARTICLE follows";
			send_logger->info("$client_id: $reply");
			$kernel->post( $sender, 'send_to_client', $client_id, $reply );
			$kernel->post( $sender, 'send_to_client', $client_id, $msg_str );
			$kernel->post( $sender, 'send_to_client', $client_id, '.' );
		}
		when("HEAD") {
			my $head = $msg->head;
			my $head_str = "$head";
			$head_str =~ s/\n*$//s; # remove separating line
			my $reply = "221 $article_id $msgid article retrieved - HEAD follows";
			send_logger->info("$client_id: $reply");
			$kernel->post( $sender, 'send_to_client', $client_id, $reply );
			$kernel->post( $sender, 'send_to_client', $client_id, $head_str );
			$kernel->post( $sender, 'send_to_client', $client_id, '.' );
		}
		when("BODY") {
			my $reply = "222 $article_id $msgid article retrieved - BODY follows";
			send_logger->info("$client_id: $reply");
			$kernel->post( $sender, 'send_to_client', $client_id, $reply );
			$kernel->post( $sender, 'send_to_client', $client_id, $msg->body->decoded );
			$kernel->post( $sender, 'send_to_client', $client_id, '.' );
		}
	}
	server_logger->debug("$client_id: sent multi-line data block");

}

# C<CAPABILITIES>
# <url:find:rfc3977.txt#line=1611>
sub nntp_cmd_capabilities {
	my ($kernel,$sender,$client_id) = @_[KERNEL,SENDER,ARG0,ARG1];
	my @cap = ( 'VERSION 2' );
	$kernel->post( $sender, 'send_to_client', $client_id, '101 Capability list' );
	$kernel->post( $sender, 'send_to_client', $client_id, (join "\r\n", @cap) );
	$kernel->post( $sender, 'send_to_client', $client_id, '.' );
}

1;
