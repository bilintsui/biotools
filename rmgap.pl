#! /usr/bin/perl
my ( $srcfile, $dstfile, $percentage ) = @ARGV;
if ( ( $srcfile eq '' ) || ( $dstfile eq '' ) ) {
	die( "Remove gaps in aligned sequences by its appearing percentage.\n\nUsage: $0 <src_file> <dst_file> <percentage>\n\nsrc_file\tThe filename of sequences to read.\ndst_file\tThe filename of sequences to write.\npercentage\tKeep bases if appearing times over (sequence total counts) * <percentage>. Defaults to 75.\n" );
}
if ( $percentage eq '' ) {
	$percentage = 75;
}
if ( ! ( ( $percentage >= 0 ) && ( $percentage <= 100 ) ) ) {
	die( "Error: The percentage must be 0-100.\n" );
}
if ( $srcfile eq '-' ) {
	$srcfile = '/dev/stdin';
}
open SRCFD, "<$srcfile";
chomp( my @source = <SRCFD> );
close SRCFD;
my $tmp_seq = '';
my @caches = ();
my $cache = {};
my $maxlength = 0;
my $maxcount = 0;
foreach $recline ( @source ) {
	if ( $recline =~ /^>/ ) {
		if ( $tmp_seq ne '' ) {
			if ( $maxlength < length( $tmp_seq ) ) {
				$maxlength = length( $tmp_seq );
			}
			@{$cache->{data}} = split //, $tmp_seq;
			@{$cache->{ndat}} = ();
			push @caches, $cache;
			$cache = {};
			$maxcount++;
			$tmp_seq = '';
		}
		$cache->{name} = $recline;
	} else {
		$tmp_seq = $tmp_seq . $recline;
	}
}
if ( $maxlength < length( $tmp_seq ) ) {
	$maxlength = length( $tmp_seq );
}
@{$cache->{data}} = split //, $tmp_seq;
push @caches, $cache;
$cache = {};
$maxcount++;
$tmp_seq = '';

my $maxgaps = $maxcount * ( 1 - ( $percentage / 100 ) );

for ( my $i = 0; $i < $maxlength; $i++ ) {
	my $curgaps = 0;
	for ( my $j = 0; $j < $maxcount; $j++ ) {
		if ( ( ${$caches[ $j ]->{data}}[ $i ] eq '-' ) || ( ${$caches[ $j ]->{data}}[ $i ] eq '' ) ) {
			$curgaps++;
		}
	}
	if ( $curgaps <= $maxgaps ) {
		for ( my $j = 0; $j < $maxcount; $j++ ) {
			push @{$caches[ $j ]->{ndat}}, ${$caches[ $j ]->{data}}[ $i ];
		}
	}
}

if ( $dstfile eq '-' ) {
	$dstfile = '/dev/stdout';
}
open DSTFD, ">$dstfile";
foreach $rec_cache( @caches ) {
	print DSTFD $rec_cache->{name} . "\n";
	print DSTFD join( '', @{$rec_cache->{ndat}} ) . "\n";
}
close DSTFD;
