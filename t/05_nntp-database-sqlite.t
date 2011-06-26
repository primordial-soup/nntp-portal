use Test::More;
use Test::Moose;

BEGIN { use_ok( 'NNTP::Portal::News::Database::SQLite'); }
require_ok( 'NNTP::Portal::News::Database::SQLite' );

does_ok( 'NNTP::Portal::News::Database::SQLite', 'NNTP::Portal::News::Database' );
does_ok( 'NNTP::Portal::News::Database::SQLite', 'NNTP::Portal::News::Database::Overview' );

done_testing;
