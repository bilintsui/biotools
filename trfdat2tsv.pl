#! /usr/bin/perl
use strict;
use warnings;
my( $arg_datfile, $arg_outfile ) = @ARGV;
if( !defined $arg_datfile ) {
	$arg_datfile = "";
}
if( !defined $arg_outfile ) {
	$arg_outfile = "";
}
if( $arg_datfile eq "-h" || $arg_datfile eq "--help" ) { die
"Convert TRF .dat file to tab-delimited table.

Usage:
	$0 < datfile > outfile
	$0 [datfile=/dev/stdin] [outfile=/dev/stdout]

[datfile]	The source file (TRF .dat), when not set or set to \"-\", reading from standard input.
[outfile]	The target file (tab-delimited table with comments), when not set or set to \"-\", write to standard output.
";
}
if( $arg_datfile eq "" || $arg_datfile eq "-" ) {
	$arg_datfile = "/dev/stdin";
}
if( $arg_outfile eq "" || $arg_outfile eq "-" ) {
	$arg_outfile = "/dev/stdout";
}
open my $fd_in, "<", $arg_datfile or die "Error: Cannot read file \"$arg_datfile\": $!\n";
open my $fd_out, ">", $arg_outfile or die "Error: Cannot write file \"$arg_outfile\": $!\n";
chomp( my @sources = <$fd_in> );
close $fd_in;
my $output_version = "";
my $output_parameters = "";
my @output_sequences = ();
my $output_records = {};
my $current_sequence = "";
foreach my $recline( @sources ) {
	if( $recline =~ /^Version (.+)$/ ) {
		my $cur_ver = $1;
		if( $output_version ne "" && $output_version ne $cur_ver ) {
			die "Error: Multiple \"Version\" lines found in your TRF .dat file, but they are different. Please check your TRF data.\n";
		}
		$output_version = $cur_ver;
	} elsif( $recline =~ /^Parameters: (.+)$/ ) {
		my $cur_paras = $1;
		if( $output_parameters ne "" && $output_parameters ne $cur_paras ) {
			die "Error: Multiple \"Parameters\" lines found in your TRF .dat file, but they are different. Please check your TRF data.\n";
		}
		$output_parameters = $cur_paras;
	} elsif( $recline =~ /^Sequence: (.+)$/ ) {
		my $cur_seq = $1;
		$current_sequence = $cur_seq;
		if( !defined $output_records->{$cur_seq} ) {
			@{$output_records->{ $cur_seq }} = ();
			push @output_sequences, $cur_seq;
		}
	} elsif( $recline =~ /^(\d+\s.+)$/ ) {
		my $cur_record = $1;
		if( $current_sequence eq "" ) {
			die "Error: Encountered record line before any \"Sequence\" line present. Please check your TRF data.\n";
		}
		$cur_record =~ s/ /\t/g;
		push @{$output_records->{$current_sequence}}, "$current_sequence\t$cur_record";
	}
}
if( $output_version eq "" ) {
	print STDERR "Warning: Could not find \"Version\" line in your TRF .dat file.\n";
}
if( $output_parameters eq "" ) {
	print STDERR "Warning: Could not find \"Parameters\" line in your TRF .dat file.\n";
}
print $fd_out "# Originally produced by TRF v$output_version, parameters: $output_parameters\n";
print $fd_out "# " . join( "\t", (
		"sequence", "start", "end", "period_size", "copy_number",
		"consensus_size", "percent_matches", "percent_indels", "score",	"base_num_a",
		"base_num_c", "base_num_g", "base_num_t", "entropy", "consensus_pattern", "original_region"
	) ) . "\n";
foreach my $recseq( @output_sequences ) {
	if( @{$output_records->{$recseq}} > 0 ) {
		foreach my $recout( @{$output_records->{$recseq}} ) {
			print $fd_out "$recout\n";
		}
	}
}
close $fd_out;
