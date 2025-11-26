#! /usr/bin/perl
use Bio::Seq;
use Getopt::Long qw( :config no_auto_abbrev no_ignore_case );

my $helpmsg = 
"Reverse entries by chromosome in JCVI-generated BED and CDS files.

Usage:
-h | --help	Show help messages.
-n | --chrname	Name of the chromosome to reverse.
-s | --chrsize	Size of the chromosome to reverse.
-b | --bedin	The BED file wants to reverse.
-B | --bedout	The BED file reverses saved to.
-c | --cdsin	The CDS file wants to reverse.
-C | --cdsout	The CDS file reverses saved to.
-w | --width	Optional, maximum bases in each line. Set 0 to disable wrapping. Default: 60.
";

# Argument processing
my $arg_help = undef;
my $arg_chrname = undef;
my $arg_chrsize = undef;
my $arg_bedin = undef;
my $arg_bedout = undef;
my $arg_cdsin = undef;
my $arg_cdsout = undef;
my $arg_width = 60;
GetOptions (
	'help|h' => \$arg_help,
	'chrname|n=s' => \$arg_chrname,
	'chrsize|s=i' => \$arg_chrsize,
	'bedin|b=s' => \$arg_bedin,
	'bedout|B=s' => \$arg_bedout,
	'cdsin|c=s' => \$arg_cdsin,
	'cdsout|C=s' => \$arg_cdsout,
	'width|w:i' => \$arg_width,
) or die( "Error: Failed parse options.\n" );

# Tests
if ( defined( $arg_help ) ) {
	die( $helpmsg );
}

if (
	! defined ( $arg_chrname ) ||
	! defined ( $arg_chrsize ) ||
	! defined ( $arg_bedin ) ||
	! defined ( $arg_bedout ) ||
	! defined ( $arg_cdsin ) ||
	! defined ( $arg_cdsout )
) {
	die( "Error: Required arguments not set. Use -h or --help for help.\n" );
}

my @bed_sources = ();

# Open source BED file
open SRCFD, "<$arg_bedin" or die( "Error: Failed to open file \"$arg_bedin\".\n" );
chomp( @bed_sources = <SRCFD> );
close SRCFD;

# Open target BED file
open DSTFD, ">$arg_bedout" or die( "Error: Failed to write file \"$arg_bedout\".\n" );

# BED reverse
my $cds_map;
foreach $bed_recline( @bed_sources ) {
	if ( $bed_recline =~ /^#/ ) {
		print DSTFD "$bed_recline\n";
	} else {
		my @fields = split /\t/, $bed_recline;
		if ( $fields[ 0 ] ne $arg_chrname ) {
			print DSTFD "$bed_recline\n";
		} else {
			$cds_map->{$fields[ 3 ]} = true;
			my $start = $arg_chrsize - $fields[ 2 ];
			my $end = $arg_chrsize - $fields[ 1 ];
			$fields[ 1 ] = $start;
			$fields[ 2 ] = $end;
			$fields[ 5 ] = $fields[ 5 ] eq '+' ? '-' : '+';
			print DSTFD join( "\t", @fields ) . "\n";
		}
	}
}
close DSTFD;

my @cds_sources = ();

# Open source CDS file
open SRCFD, "<$arg_cdsin" or die( "Error: Failed to open file \"$arg_cdsin\".\n" );
chomp( @cds_sources = <SRCFD> );
close SRCFD;

# Open target CDS file
open DSTFD, ">$arg_cdsout" or die( "Error: Failed to write file \"$arg_cdsout\".\n" );

# CDS reverse
my $curseqname = '';
my $curseqcontent = '';
my $curseqcontent_part = '';
foreach $cds_recline( @cds_sources ) {
	if ( $cds_recline =~ /^>/ ) {
		if ( $curseqcontent ne '' ) {
			$curseqcontent = Bio::Seq->new( -seq => $curseqcontent, -alphabet => 'dna' )->revcom->seq;
			while ( ( $arg_width != 0 ) && ( length( $curseqcontent ) > 60 ) ) {
				$curseqcontent_part = substr( $curseqcontent, 0, $arg_width );
				print DSTFD "$curseqcontent_part\n";
				$curseqcontent = substr( $curseqcontent, $arg_width );
			}
			print DSTFD "$curseqcontent\n";
			$curseqcontent = '';
		}
		print DSTFD "$cds_recline\n";
		$curseqname = $cds_recline;
		$curseqname =~ s/^>//;
	} else {
		if ( ! defined( $cds_map->{$curseqname} ) ) {
			print DSTFD "$cds_recline\n";
		} else {
			$curseqcontent = $curseqcontent . $cds_recline;
		}
	}
}
