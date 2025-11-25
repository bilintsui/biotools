#! /usr/bin/perl
use strict;
use warnings;
eval {
	require Sort::Key::Natural;
	Sort::Key::Natural->import( "natsort" );
	1;
} or die "Error: This script requires perl module \"Sort::Key::Natural\", but not found on your machine.\n\n";
my( $arg_infile, $arg_outfile ) = @ARGV;
if( !defined $arg_infile ) {
	$arg_infile = "";
}
if( !defined $arg_outfile ) {
	$arg_outfile = "";
}
if( $arg_infile eq "-h" || $arg_infile eq "--help" ) { die
"Merge BED entries if they contained in or overlapped with other entries.

Usage:
	$0 < infile > outfile
	$0 [infile=/dev/stdin] [outfile=/dev/stdout]

[infile]	The source BED file, when not set or set to \"-\", read from standard input.
[outfile]	The target BED file, when not set or set to \"-\", write to standard output.
";
}
if( $arg_infile eq "" || $arg_infile eq "-" ) {
	$arg_infile = "/dev/stdin";
}
if( $arg_outfile eq "" || $arg_outfile eq "-" ) {
	$arg_outfile = "/dev/stdout";
}
open my $fd_in, "<", $arg_infile or die "Error: Cannot read file \"$arg_infile\": $!\n";
open my $fd_out, ">", $arg_outfile or die "Error: Cannot write file \"$arg_outfile\": $!\n";
chomp( my @sources = <$fd_in> );
close $fd_in;
my $entries = {};
my $cur_line = 1;
foreach my $recline( @sources ) {
	my @cur_fields = split /\t/, $recline;
	if( @cur_fields < 3 ) {
		warn "Warning: Ignored incomplete BED entry, at line $cur_line.\n";
		$cur_line++;
		next;
	}
	my $cur_seqname = $cur_fields[0];
	my $cur_start = $cur_fields[1];
	my $cur_end = $cur_fields[2];
	if( !$cur_start=~/^\d+$/ || !$cur_end=~/^\d+$/ ) {
		warn "Warning: Ignored invalid BED entry, at line $cur_line.\n";
		$cur_line++;
		next;
	}
	if( !defined( $entries->{$cur_seqname}->{$cur_start} ) || ( $cur_end > $entries->{$cur_seqname}->{$cur_start} ) ) {
		$entries->{$cur_seqname}->{$cur_start} = $cur_end;
	}
	$cur_line++;
}
my $outputs = {};
foreach my $recseq( natsort( keys %{$entries} ) ) {
	my $laststart = -1;
	foreach my $recstart( natsort( keys %{$entries->{$recseq}} ) ) {
		my $recend = $entries->{$recseq}->{$recstart};
		if( $laststart == -1 ) {
			$outputs->{$recseq}->{$recstart} = $recend;
			$laststart = $recstart;
			next;
		}
		if( $laststart < $recstart && $recstart < $outputs->{$recseq}->{$laststart} ) {
			if( $outputs->{$recseq}->{$laststart} < $recend ) {
				$outputs->{$recseq}->{$laststart} = $recend;
			}
		} else {
			$outputs->{$recseq}->{$recstart} = $recend;
			$laststart = $recstart;
			next;
		}
	}
}
foreach my $recseq( natsort( keys %{$outputs} ) ) {
	foreach my $recstart( natsort( keys %{$outputs->{$recseq}} ) ) {
		my $recend = $outputs->{$recseq}->{$recstart};
		print $fd_out "$recseq\t$recstart\t$recend\n";
	}
}
