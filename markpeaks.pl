#! /usr/bin/perl
use strict;
use warnings;

my $helpmsg =
"Validate whether peaks/centromeres are fully contained in centromeres/genomes, merge fragments, and mark peaks by length.


Usage: $0 <genome_file> <centromere_list> <peak_list> [peak_length_threshold=1000] [output_bed=/dev/stdout]

genome_file		The genome file.
centromere_list		A tab-delimited table of centromeric regions, at least have sequence name, start position, and end position (both 1-start).
peak_list		A tab-delimited table of peak regions, at least have sequence name, start position, and end position (both 1-start).
peak_length_threshold	Optional, marking peaks as \"peak_short\" when the length of a peak is shorter than this, otherwise marks \"peak_long\".
			When set to 0, peaks will not be classified, marking as \"peak\". Defaults: 1000.
output_bed		Optional, the file name of where results outputs. When not set or set to \"-\", will outputs to standard output.


The result is in BED format, with first three columns as sequence name, start position (0-start), end position (1-start).

Type of each records store as the fourth column (defined as \"name\" in BED specifications), possible values:
	genome, non_centromere, centromere, non_peak, peak, peak_short, peak_long";

eval {
	require Bio::SeqIO;
	Bio::SeqIO->import();
	1;
} or die "[CRIT] This script requires perl module \"Bio::SeqIO\", but not found on your machine.\n\n$helpmsg\n";
eval {
	require Scalar::Util;
	Scalar::Util->import( "looks_like_number" );
	1;
} or die "[CRIT] This script requires perl module \"Scalar::Util\", but not found on your machine.\n\n$helpmsg\n";
eval {
	require Sort::Key::Natural;
	Sort::Key::Natural->import( "natsort" );
	1;
} or die "[CRIT] This script requires perl module \"Sort::Key::Natural\", but not found on your machine.\n\n$helpmsg\n";

my( $arg_genome, $arg_centro, $arg_peak, $arg_peaklen_threshold, $arg_output ) = @ARGV;
if( !$arg_genome || !$arg_centro || !$arg_peak ) {
	die "$helpmsg\n";
}
if( !defined( $arg_peaklen_threshold ) || !looks_like_number( $arg_peaklen_threshold ) || $arg_peaklen_threshold < 0 ) {
	$arg_peaklen_threshold = 1000;
}
if( !defined( $arg_output ) || $arg_output eq "" || $arg_output eq "-" ) {
	$arg_output = "/dev/stdout";
}

open my $fd_genome, "<", $arg_genome or die "[CRIT] Cannot open file \"$arg_genome\": $!.\n";
close $fd_genome;
open my $fd_centro, "<", $arg_centro or die "[CRIT] Cannot open file \"$arg_centro\": $!.\n";
open my $fd_peak, "<", $arg_peak or die "[CRIT] Cannot open file \"$arg_peak\": $!.\n";
open my $fd_out, ">", $arg_output or die "[CRIT] Cannot write file \"$arg_output\": $!.\n";

my $outputs;

print STDERR "[INFO] Reading genome...";
my $genomes;
my $seq_in = Bio::SeqIO->new( -file => $arg_genome, -format => "fasta" );
while( my $seq_obj = $seq_in->next_seq() ) {
	$genomes->{$seq_obj->id()}->{len} = $seq_obj->length();
	$genomes->{$seq_obj->id()}->{map} = [ (0) x $seq_obj->length() ];
	$outputs->{$seq_obj->id()} = [ { "start" => 0, "end" => $seq_obj->length(), "type" => "genome" } ];
}

print STDERR "\n[INFO] Reading centromeres...";
my $valid_centromeres;
foreach my $recline( <$fd_centro> ) {
	my @centro = split /\t/, $recline;
	if( $#centro < 2 ) {
		print STDERR "[WARN] Ignored incomplete centromere entry \"$recline\".\n";
		next;
	}
	my( $centro_seqid, $centro_start, $centro_end ) = @centro;
	if( ( $centro_start <= 0 ) || ( $centro_start >= $centro_end ) ) {
		print STDERR "[WARN] Ignored invalid centromere entry \"$recline\".\n";
		next;
	}
	if( !defined( $genomes->{$centro_seqid} ) ) {
		print STDERR "[WARN] Ignored centromere entry \"$recline\", because \"$centro_seqid\" cannot be found in the genome file.\n";
		next;
	}
	if( $centro_end > $genomes->{$centro_seqid}->{len} ) {
		print STDERR "[WARN] Ignored centromere entry \"$recline\", because it is beyond its parent sequence.\n";
		next;
	}
	if( !defined( $valid_centromeres->{$centro_seqid} ) ) {
		@{$valid_centromeres->{$centro_seqid}} = ();
	}
	push( @{$valid_centromeres->{$centro_seqid}}, { "seqid" => $centro_seqid, "start" => $centro_start, "end" => $centro_end } );
	splice( @{$genomes->{$centro_seqid}->{map}}, $centro_start - 1, $centro_end - $centro_start + 1, (1) x ( $centro_end - $centro_start + 1 ) );
}

print STDERR "\n[INFO] Reading peaks...";
foreach my $recline( <$fd_peak> ) {
	my @peak = split /\t/, $recline;
	if( $#peak < 2 ) {
		print STDERR "[WARN] Ignored incomplete peak entry \"$recline\".\n";
		next;
	}
	my( $peak_seqid, $peak_start, $peak_end ) = @peak;
	if( ( $peak_start <= 0 ) || ( $peak_start >= $peak_end ) ) {
		print STDERR "[WARN] Ignored invalid peak entry \"$recline\".\n";
		next;
	}
	if( !defined( $valid_centromeres->{$peak_seqid} ) ) {
		print STDERR "[WARN] Ignored peak entry \"$recline\", because \"$peak_seqid\" cannot be found in the centromere list.\n";
		next;
	}
	if( $peak_end > $genomes->{$peak_seqid}->{len} ) {
		print STDERR "[WARN] Ignored peak entry \"$recline\", because it is beyond its parent sequence.\n";
		next;
	}
	my $peak_foundcentro = 0;
	foreach my $reccentro( @{$valid_centromeres->{$peak_seqid}} ) {
		if( ( $reccentro->{seqid} eq $peak_seqid ) && ( $reccentro->{start} <= $peak_start ) && ( $reccentro->{end} >= $peak_end ) ) {
			splice( @{$genomes->{$peak_seqid}->{map}}, $peak_start - 1, $peak_end - $peak_start + 1, (2) x ( $peak_end - $peak_start + 1 ) );
			$peak_foundcentro = 1;
			last;
		}
	}
	if( $peak_foundcentro == 0 ) {
		print STDERR "[WARN] Ignored peak entry \"$recline\", because it is out of any known centromere regions.\n";
	}
}

my @output_predef_types = ( "non_centromere", "non_peak", "peak" );
foreach my $recseq( natsort( keys %{$genomes} ) ) {
	print STDERR "\n[INFO] Processing mappings on \"$recseq\"...";
	my @positions = ( 0 );
	my $lastflag = $genomes->{$recseq}->{map}[ 0 ];
	for( my $i = 1; $i < $genomes->{$recseq}->{len}; $i++ ) {
		if( $genomes->{$recseq}->{map}[ $i ] != $lastflag ) {
			push @positions, $i;
			$lastflag = $genomes->{$recseq}->{map}[ $i ];
		}
	}
	push @positions, $genomes->{$recseq}->{len};
	my $cached_index = -1;
	for( my $i = 0; $i < $#positions; $i++ ) {
		my $cur_type = $genomes->{$recseq}->{map}[ $positions[ $i ] ];
		my $cur_type_suffix = "";

		if( ( $cached_index == -1 ) && ( ( $cur_type == 1 ) || ( $cur_type == 2 ) ) ) {
			push @{$outputs->{$recseq}}, { "start" => $positions[ $i ], "end" => -1, "type" => "centromere" };
			$cached_index = $#{$outputs->{$recseq}};
		}
		if( ( $cached_index != -1 ) && ( ( $cur_type != 1 ) && ( $cur_type != 2 ) ) ) {
			$outputs->{$recseq}[ $cached_index ]->{end} = $positions[ $i ];
			$cached_index = -1;
		}
		if( ( $cur_type == 2 ) && ( $arg_peaklen_threshold > 0 ) ) {
			if( ( $positions[ $i + 1 ] - $positions[ $i ] ) < $arg_peaklen_threshold ) {
				$cur_type_suffix = "_short";
			} else {
				$cur_type_suffix = "_long";
			}
		}
		push @{$outputs->{$recseq}}, { "start" => $positions[ $i ], "end" => $positions[ $i + 1 ], "type" => $output_predef_types[ $cur_type ] . $cur_type_suffix };
	}
	if( $cached_index != -1 ) {
		$outputs->{$recseq}[ $cached_index ]->{end} = $genomes->{$recseq}->{len};
	}
}

print STDERR "\n[INFO] Outputting results...";
foreach my $recseq( natsort( keys %{$outputs} ) ) {
	foreach my $recentry( @{$outputs->{$recseq}} ) {
		print $fd_out "$recseq\t$recentry->{start}\t$recentry->{end}\t$recentry->{type}\n";
	}
}

print STDERR "\n";

close $fd_out;
close $fd_peak;
close $fd_centro;
