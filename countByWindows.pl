#! /usr/bin/perl
use POSIX;
my( $genomeSize, $windowSize, $noteString, $gffFile, $resultFile ) = @ARGV;
if( $genomeSize eq '' || $windowSize eq '' ) {
	die
"Count sequence repeat times in genome by windows.

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
for( my $i = 0; ( $i * $windowSize ) < $genomeSize; $i++ ) {
	my $tmp;
	$tmp->{idx} = $i + 1;
	$tmp->{min} = $windowSize * $i + 1;
	$tmp->{max} = $windowSize * ( $i + 1 );
	$tmp->{num} = 0;
	push @cache, $tmp;
}
open SRCFD, "<$gffFile";
open DSTFD, ">$resultFile";
foreach $recline( <SRCFD> ) {
	chomp( $recline );
	if( ! ( $recline =~ /^#/ ) ) {
		my @fields = split /\t/, $recline;
		my $start = $fields[ 3 ];
		my $end = $fields[ 4 ];
		my $length = $end - $start + 1;
		my $index = floor( $start / $windowSize );
		if( $end > $cache[ $index ]->{max} ) {
			my $lenP1 = $cache[ $index ]->{max} - $start + 1;
			my $lenP2 = $end - $cache[ $index ]->{max};
			$cache[ $index ]->{num} = $cache[ $index ]->{num} + $lenP1 / ( $lenP1 + $lenP2 );
			$cache[ $index + 1 ]->{num} = $cache[ $index + 1 ]->{num} + $lenP2 / ( $lenP1 + $lenP2 );

		} else {
			$cache[ $index ]->{num}++;
		}
	}
}
close SRCFD;
print DSTFD "window_id\twindow_start\twindow_end\tcount$noteHeader\n";
foreach $recitem( @cache ) {
	print DSTFD $recitem->{idx} . "\t" . $recitem->{min} . "\t" . $recitem->{max} . "\t" . $recitem->{num} . "$noteString\n";
}
close DSTFD;
