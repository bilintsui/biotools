#! /usr/bin/perl
use POSIX;
my( $genomeSize, $windowSize, $noteString, $gffFile, $resultFile ) = @ARGV;
if( $genomeSize eq '' || $windowSize eq '' ) {
	die
"Calculate fraction of lengths of marked regions in individual windows.

Usage: $0 <genome_size> <window_size> [note_string] [gff_file] [output_file]

genome_size	Size of the source sequence (usually chromosome).
window_size	Size of the sequence range (window) to count repeats.
note_string	Optional string, to add a note at the last column.
gff_file	Source GFF file. If unset or using \"-\", will read from standard input.
output_file	Result file. If unset or using \"-\", will write to standard output.

Note: This script doesn't support slipping windows.
";
}
my $noteHeader = '';
if( $noteString ne '' ) {
	$noteString = "\t$noteString";
	$noteHeader = "\tnote";
}
if( $gffFile eq '' || $gffFile eq '-' ) {
	$gffFile = '/dev/stdin'
}
if( $resultFile eq '' || $resultFile eq '-' ) {
	$resultFile = '/dev/stdout'
}
my @cache = ();
$cache[ $genomeSize - 1 ] = 0;
open SRCFD, "<$gffFile";
open DSTFD, ">$resultFile";
foreach $recline( <SRCFD> ) {
	chomp( $recline );
	if( ! ( $recline =~ /^#/ ) ) {
		my @fields = split /\t/, $recline;
		my $start = $fields[ 3 ];
		my $end = $fields[ 4 ];
		for( my $i = $start - 1; $i < $end; $i++ ) {
			$cache[ $i ] = 1;
		}
	}
}
print DSTFD "windowID\twindowStart\twindowEnd\tfrac$noteHeader\n";
for( my $i = 0; ( $i * $windowSize ) < $genomeSize; $i++ ) {
	my $curWindowStart = $windowSize * $i + 1;
	my $curWindowEnd = $windowSize * ( $i + 1 );
	if( $curWindowEnd > $genomeSize ) {
		$curWindowEnd = $genomeSize;
	}
	my $curLenSum = 0;
	for( my $j = $curWindowStart; $j <= $curWindowEnd; $j++ ) {
		$curLenSum = $curLenSum + $cache[ $j - 1 ];
	}
	my $curLenFrac = $curLenSum / $windowSize;
	print DSTFD "${i}\t${curWindowStart}\t${curWindowEnd}\t${curLenFrac}${noteString}\n";
}
