package NNTP::Portal::News::Database::SQLite;

use Moose;
use MooseX::Types::DateTime;
use MooseX::Method::Signatures;

use NNTP::Message;
use NNTP::Portal::Util;

use DateTime;
use Carp;

# TODO move this to a more general place
use Net::Domain qw(hostfqdn);

has servername => (
	is => 'ro',
	isa => 'Str',
	default => sub {
		hostfqdn;
	}
);

method init {
	# we add a funtion for WILDMAT expressions
	# See L<http://www.justatheory.com/computers/databases/sqlite/add_regexen.html>
	$self->dbh->{sqlite_unicode} = 1;
	$self->dbh->func('wildmat', 2, sub {
		my ($wildmat, $string) = @_;
		return $string =~ NNTP::Portal::Util->wildmat_re($wildmat);
	}, 'create_function');
	$self->create_tables;
}
method end {
	$self->dbh->disconnect;
}

# TODO filters here?
method get_message(Str $msgID) {
	my $msgID_sth = $self->dbh->prepare_cached( q/SELECT message FROM msgid WHERE msgid = ?/ ); # 1
	$self->log->debug("Getting message-id $msgID");
	$msgID_sth->execute($msgID) or croak $msgID_sth;
	my $row = $msgID_sth->fetchrow_arrayref();
	$msgID_sth->finish;
	return undef unless defined $row;
	my $msg = NNTP::Message->read( $row->[0] );
	return $msg;
}

# DONE
method register_message(NNTP::Message $msg, ClassName $plugin) {
	my $msgID = $msg->get_messageID;

	if( $self->get_message($msgID) ) {
		$self->log->info("$msgID: Already exists");
		return;
	}

	my $groups = $msg->get_newsgroups();
	my %xref;
	for my $newsgroup (@$groups) {
		# NOTE perhaps only add to xref if the group is already registered (see TODO file)
		# or only generate the Xref: field as a filter when the message is retrieved
		my $article_no = $self->get_next_article_id($newsgroup);
		$xref{ $newsgroup } = $article_no;
		my $insert_xref_sth = 	$self->dbh->prepare_cached( q/INSERT OR IGNORE INTO xref VALUES( ? , ? , ? )/ ); # 3

		$insert_xref_sth->execute( $msgID, $newsgroup, $article_no ) or croak $insert_xref_sth->errstr;
	}

	$msg->set_xref( $self->servername, \%xref );
	if( $self->log->is_debug ) {
		$self->log->debug( "$msgID : Xref: ", $msg->study('xref') );
	}

	my $content = $msg->string;

	my $insert_msg_sth =  $self->dbh->prepare_cached(q/INSERT OR IGNORE INTO msgid VALUES( ? , ?, ?)/); # 2
	$insert_msg_sth->execute($msgID, $content, $plugin) or croak $insert_msg_sth->errstr;
}

# DONE
method get_overview(Str $msgID, Maybe[Str] $newsgroup) {
	my $msg = NNTP::Message->read($self->get_message($msgID));
	my $xref = $msg->get_xref;
	my $article_id = 0;
	$article_id = $xref->{$newsgroup} if defined $newsgroup
		and defined $xref->{$newsgroup};
	return ( $article_id, NNTP::Message::Overview->get_msg_required($msg),
		$msg->study('xref') );
}

# DONE
method get_msgid(Str $newsgroup, Str $article_id ) {
	my $msgid_sth = $self->dbh->prepare_cached(q/
		SELECT msgid FROM xref WHERE newsgroup = ? AND article_id = ?
	/);
	$self->log->debug("Retrieving message-id for $newsgroup:$article_id");
	$msgid_sth->execute($newsgroup, $article_id) or croak $msgid_sth->errstr;
	my $msgid = ( $msgid_sth->fetchrow_arrayref() // [undef] )->[0];
	$msgid_sth->finish;
	return $msgid;
}

# DONE
method get_overview_fmt_extra {
	return wantarray ? @{$self->overview_extra} : $self->overview_extra;
}

# DONE
method get_max_article_id(Str $newsgroup) {
	my $max_art_id_sth = $self->dbh->prepare_cached(
		q/SELECT MAX(article_id) FROM xref WHERE newsgroup = ?/
	);

	$max_art_id_sth->execute($newsgroup) or croak $max_art_id_sth->errstr;
	my $max = $max_art_id_sth->fetchrow_arrayref()->[0];
	$max_art_id_sth->finish;
	return $max;
}

# DONE
method get_new_newsgroups(DateTime $time) {
	my $new_newsgroups = $self->dbh->prepare_cached(
		q/SELECT newsgroup FROM newsgroup WHERE time <= ?/
	);
	my $unix_time = $time->epoch;
	$new_newsgroups->execute($unix_time) or croak $new_newsgroups->errstr;
	return $new_newsgroups->fetchall_arrayref();
}

# DONE
method get_newsgroup_desc(Str $newsgroup) {
	my $newsgroup_desc = $self->dbh->prepare_cached(
		q/SELECT desc FROM newsgroup WHERE newsgroup = ?/
	);
	$newsgroup_desc->execute($newsgroup) or croak $newsgroup_desc->errstr;
	my $ng_desc = ($newsgroup_desc->fetchrow_arrayref() // [undef] )->[0];
	$newsgroup_desc->finish;
	return $ng_desc;
}

# DONE
method get_newsgroups {
	my $newsgroups = $self->dbh->prepare_cached(q/SELECT newsgroup,desc from newsgroup/);
	my $hr = $self->dbh->selectall_hashref($newsgroups, "newsgroup") or croak $newsgroups->errstr;
	my %newsgroups = map { $_ => $hr->{$_}->{desc} } keys %$hr;
	return \%newsgroups;
}

# DONE
method register_newsgroup(Str $newsgroup, Str $desc, ClassName $plugin) {
	# TODO: update mechanism, rather than just ignore
	my $ins_newsgroup = $self->dbh->prepare_cached(
		q/INSERT OR IGNORE INTO newsgroup VALUES( ? , ? , ?, ?)/
	);

	$ins_newsgroup->execute($newsgroup, $desc, $plugin,
		DateTime->now->epoch) or croak $ins_newsgroup->errstr;
}

method get_newsgroup_stats(Str $newsgroup) {
	my $ng_stats_sth = $self->dbh->prepare_cached(
		q/SELECT MIN(article_id), MAX(article_id), COUNT(article_id)
			FROM xref
			WHERE newsgroup = ? /);
	$ng_stats_sth->execute($newsgroup) or croak $ng_stats_sth->errstr;
	my $aref = $ng_stats_sth->fetchrow_arrayref;
	$ng_stats_sth->finish;
	my %hs;
	@hs{qw/low high count/} = @$aref[0..2];
	return \%hs;
}

# DONE
method get_plugin(Str $type, Str $value) {
	if($type eq 'newsgroup') {
		my $plugin_news = $self->dbh->prepare_cached(q/SELECT plugin from newsgroup WHERE newsgroup = ?/);
		$plugin_news->execute($value) or croak $plugin_news->errstr;
		return $plugin_news->fetchrow_arrayref()->[0];
	} elsif($type eq 'message') {
		my $plugin_msg = $self->dbh->prepare_cached(q/SELECT plugin from msgid WHERE msgid = ?/);
		$plugin_msg->execute($value) or croak $plugin_msg->errstr;
		return $plugin_msg->fetchrow_arrayref()->[0];
	}
	return;
}

# Private methods
method create_tables {
	# NOTE: VARCHAR(998) comes from RFC 2822

	# 2 columns
	# 
	# Table: msgid
	# msgid : contains the message id (<123456@example.net>)
	# message: contains the entire content of the RFC 2822 message
	# plugin: the plugin that registered a message
	$self->log->info("Checking the existence of table 'msgid'");
	my $create_msgid_table = q/CREATE TABLE IF NOT EXISTS msgid (
		msgid VARCHAR(998) PRIMARY KEY NOT NULL,
		message TEXT NOT NULL,
		plugin TEXT NOT NULL
	)/;
	my $rv = $self->dbh->do($create_msgid_table) or croak $self->dbh->errstr;

	# 3 columns
	# Table: newsgroup
	# newsgroup: name of newsgroup (comp.lang.perl)
	# desc: description of newsgroup (Talking about things)
	# plugin: the plugin that registered the newsgroup
	# time: when the group was registered in Unix time
	$self->log->info("Checking the existence of table 'newsgroup'");
	my $create_newsgroup_table = q/CREATE TABLE IF NOT EXISTS newsgroup (
		newsgroup TEXT PRIMARY KEY NOT NULL,
		desc TEXT,
		plugin TEXT NOT NULL,
		time INTEGER NOT NULL
	)/;
	$rv &= $self->dbh->do($create_newsgroup_table) or croak $self->dbh->errstr;

	# 3 columns
	# Table: xref
	# msgid: message ID as in Table: msgid
	# newsgroup: newsgroup name as in Table: newsgroup
	# article_id: integer indicating the article ID in a given newsgroup
	$self->log->info("Checking the existence of table 'xref'");
	my $create_xref_table = q/CREATE TABLE IF NOT EXISTS xref (
		msgid VARCHAR(998) NOT NULL,
		newsgroup TEXT NOT NULL,
		article_id INTEGER NOT NULL,
		FOREIGN KEY (msgid) REFERENCES msgid(msgid),
		FOREIGN KEY (newsgroup) REFERENCES newsgroup(newsgroup),
		PRIMARY KEY ( msgid, newsgroup )
	)/;
	$rv &= $self->dbh->do($create_xref_table) or croak $self->dbh->errstr;

	return $rv;
}

has overview_extra => (
	is => 'ro',
	isa => 'ArrayRef',
	default => sub {
		[ "Xref:full" ];
	}
);

with qw/ NNTP::Portal::News::Database::DBI NNTP::Portal::News::Database::Overview
	MooseX::Log::Log4perl/;

no Moose;
__PACKAGE__->meta->make_immutable;

=head1 NAME

NNTP::Portal::News::Database::SQLite - SQLite implementation of L<NNTP::Portal::News::Database>

=cut
