package ZonemasterDB::SQLite v0.0.1;
use Moose;
use utf8;
use 5.14.0;

use Data::Dumper;
use DBI qw(:utils);
use JSON;
use Digest::MD5 qw(md5_hex);

use ZonemasterDB;

use FindBin qw($RealScript $Script $RealBin $Bin);
##################################################################
my $PROJECT_NAME = "Zonemaster-Backend";

my $SCRITP_DIR = __FILE__;
$SCRITP_DIR = $Bin unless ($SCRITP_DIR =~ /^\//);

#warn "SCRITP_DIR:$SCRITP_DIR\n";
#warn "RealScript:$RealScript\n";
#warn "Script:$Script\n";
#warn "RealBin:$RealBin\n";
#warn "Bin:$Bin\n";
#warn "__PACKAGE__:".__PACKAGE__;
#warn "__FILE__:".__FILE__;

my ($PROD_DIR) = ($SCRITP_DIR =~ /(.*?\/)$PROJECT_NAME/);
#warn "PROD_DIR:$PROD_DIR\n";

my $PROJECT_BASE_DIR = $PROD_DIR.$PROJECT_NAME."/";
#warn "PROJECT_BASE_DIR:$PROJECT_BASE_DIR\n";
unshift(@INC, $PROJECT_BASE_DIR);
##################################################################

unshift(@INC, $PROD_DIR."Zonemaster-Backend") unless $INC{$PROD_DIR."Zonemaster-Backend"};
require BackendConfig;

with 'ZonemasterDB';

my $connection_string = BackendConfig->DB_connection_string();

has 'dbh' => (
	is => 'ro',
	isa => 'DBI::db',
	default => sub { DBI->connect($connection_string, {RaiseError => 1, AutoCommit => 1}) },
);

sub create_db {
	my ($self) = @_;

	####################################################################
	# TEST RESULTS
	####################################################################
	$self->dbh->do('DROP TABLE IF EXISTS test_specs') or die "SQLite Fatal error: " . $self->dbh->errstr();

	$self->dbh->do('DROP TABLE IF EXISTS test_results') or die "SQLite Fatal error: " . $self->dbh->errstr();

	$self->dbh->do('CREATE TABLE test_results (
					id integer PRIMARY KEY,
					batch_id integer NULL,
					creation_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
					test_start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
					test_end_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
					priority integer DEFAULT 10,
					progress integer DEFAULT 0,
					params_deterministic_hash character varying(32),
					params json1 NOT NULL,
					results json DEFAULT NULL
			)
	') or die "SQLite Fatal error: " . $self->dbh->errstr();

	####################################################################
	# BATCH JOBS
	####################################################################
	$self->dbh->do('DROP TABLE IF EXISTS batch_jobs') or die "SQLite Fatal error: " . $self->dbh->errstr();

	$self->dbh->do('CREATE TABLE batch_jobs (
					id integer PRIMARY KEY,
					username character varying(50) NOT NULL,
					creation_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL
			)
	') or die "SQLite Fatal error: " . $self->dbh->errstr();

	####################################################################
	# USERS
	####################################################################
	$self->dbh->do('DROP TABLE IF EXISTS users');
	$self->dbh->do('CREATE TABLE users (
					id integer primary key,
					user_info json DEFAULT NULL
			)
	') or die "SQLite Fatal error: " . $self->dbh->errstr();
	
	return 1;
}

sub user_exists_in_db {
	my ($self, $user) = @_;
	my $user_id;

	my $href = $self->dbh->selectall_hashref( "SELECT * FROM users", 'id' );
	foreach my $id (keys %$href) {
		my $user_info = decode_josn($href->{$id}->{user_info});
		$user_id = $id if ($user_info->{username} eq $user);
	}

	return $user_id;
}

sub add_api_user_to_db {
	my ($self, $user_info) = @_;

	my $nb_inserted = $self->dbh->do( "INSERT INTO users (user_info) VALUES(".$self->dbh->quote(encode_json($user_info)).")" );

	return $nb_inserted; 
};

sub user_authorized {
	my ($self, $user, $api_key) = @_;

	my $user_id;
	
	my $href = $self->dbh->selectall_hashref( "SELECT * FROM users", 'id' );
	foreach my $id (keys %$href) {
		my $user_info = decode_josn($href->{$id}->{user_info});
		if ($user_info->{username} eq $user && $user_info->{api_key} eq $api_key) {
			$user_id = $id;
		}
	}

	return $user_id;
}

sub create_new_batch_job {
	my ($self, $username) = @_;

	my ($batch_id, $creaton_time) = $self->dbh->selectrow_array( "
			SELECT 
				batch_id, 
				batch_jobs.creation_time AS batch_creation_time 
			FROM 
				test_results 
			JOIN batch_jobs 
				ON batch_id=batch_jobs.id 
				AND username=".$self->dbh->quote($username).
			" WHERE 
				test_results.progress<>100
			LIMIT 1
			") ;
			
	die "You can't create a new batch job, job:[$batch_id] started on:[$creaton_time] still running " if ($batch_id);
	
	my ($new_batch_id) = $self->dbh->selectrow_array("INSERT INTO batch_jobs (username) VALUES(".$self->dbh->quote($username).") RETURNING id");

	return $new_batch_id;
}

sub create_new_test {
	my ($self, $domain, $test_params, $minutes_between_tests_with_same_params, $priority, $batch_id) = @_;
	my $result;

	$test_params->{domain} = $domain;
	my $js = JSON->new;
	$js->canonical(1);
	my $encoded_params = $js->encode($test_params);
	my $test_params_deterministic_hash = md5_hex($encoded_params);
	
	my $query = "INSERT INTO test_results (batch_id, priority, params_deterministic_hash, params) SELECT ".
				$self->dbh->quote($batch_id).", ".
				$self->dbh->quote(5).", ".
				$self->dbh->quote($test_params_deterministic_hash).", ".
				$self->dbh->quote($encoded_params).
				" WHERE NOT EXISTS (SELECT * FROM test_results WHERE params_deterministic_hash='$test_params_deterministic_hash' AND creation_time > datetime('now', '-$minutes_between_tests_with_same_params minute'))";
				
	my $nb_inserted = $self->dbh->do($query);
	
	($result) = $self->dbh->selectrow_array("SELECT MAX(id) AS id FROM test_results WHERE params_deterministic_hash='$test_params_deterministic_hash'");
	
	return $result;
}

sub test_progress {
	my($self, $test_id, $progress) = @_;
	
	$self->dbh->do("UPDATE test_results SET progress=$progress WHERE id=$test_id") if ($progress);
	
	my ($result) = $self->dbh->selectrow_array("SELECT progress FROM test_results WHERE id=$test_id");
	
	return $result;
}

sub get_test_params {
	my($self, $test_id) = @_;
	
	my $result;
	
	my ($params_json) = $self->dbh->selectrow_array("SELECT params FROM test_results WHERE id=$test_id");
	eval {
		$result = decode_json($params_json);
	};
	die $@ if $@;
	
	return $result;
}

sub test_results {
	my($self, $test_id, $results) = @_;
	
	$self->dbh->do( "UPDATE test_results SET progress=100, test_end_time=datetime('now'), results = ".$self->dbh->quote($results)." WHERE id=$test_id " ) if ($results);
	
	my $result;
	eval {
		my ($hrefs) = $self->dbh->selectall_hashref("SELECT * FROM test_results WHERE id=$test_id", 'id');
		$result = $hrefs->{$test_id};
		$result->{params} = decode_json($result->{params});
		$result->{results} = decode_json($result->{results});
	};
	die $@ if $@;
	
	return $result;
}


sub get_test_history {
	my($self, $p) = @_;
	
	my @results;
	my $quoted_domain = $self->dbh->quote($p->{frontend_params}->{domain});
	$quoted_domain =~ s/'/"/g;
	my $query = "SELECT id, creation_time, params FROM test_results WHERE params like '\%\"domain\":$quoted_domain\%' ORDER BY id DESC LIMIT $p->{limit} OFFSET $p->{offset} ";
	my $sth1 = $self->dbh->prepare($query);
	$sth1->execute;
	while (my $h = $sth1->fetchrow_hashref) {
		push(@results, { id => $h->{id}, creation_time => $h->{creation_time}, advanced_options => $h->{advanced_options} });
	}
	
	return \@results;
}


no Moose;
__PACKAGE__->meta()->make_immutable();

1;