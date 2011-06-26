#!/usr/bin/perl

use Test::More;

BEGIN { use_ok( 'NNTP::Message::Overview' ); }
require_ok( 'NNTP::Message::Overview' );

my $over = 'NNTP::Message::Overview';

is( $over->over_line( '0', 'a', "b\tc \t\t",'d') ,  "0\ta\tb c   \td" , "array" );
is( $over->over_line([ '0', 'a', "b\tc \t\t",'d']) ,  "0\ta\tb c   \td", "arrayref" );

is( $over->over_line( 'a', '', 'b' ) ,  "a\t\tb" , "empty field" );

is( $over->over_line( 'a', undef, 'b' ) ,  "a\t\tb" , "empty field (w/ undef)" );
is( $over->over_line( undef, undef, undef ) ,  "\t\t" , "all undef" );

done_testing;
