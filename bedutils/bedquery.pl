#! /usr/bin/perl
use strict;
use warnings;
eval {
	require Sort::Key::Natural;
	Sort::Key::Natural->import( "natsort" );
	1;
} or die "Error: This script requires perl module \"Sort::Key::Natural\", but not found on your machine.\n\n";

sub bed_read {
	my( $sources_ref, $name ) = @_;
	my @sources = @$sources_ref;
	my $cache = {};
	my $reclinenum = 1;
	foreach my $recline( @sources ) {
		my @recfields = split /\t/, $recline;
		if( @recfields < 3 ) {
			warn "Warning: Ignored incomplete $name BED entry on line $reclinenum.\n";
			next;
		}
		my $recseq = shift @recfields;
		my $recstart = shift @recfields;
		my $recend = shift @recfields;
		my $recattr = join "\t", @recfields;
		if( $recstart !~ /^\d+$/ || $recend !~ /^\d+$/ || $recstart > $recend ) {
			warn "Warning: Ignored invalid $name BED entry on line $reclinenum.\n";
			next;
		}
		$recstart+=0;
		$recend+=0;
		$cache->{$recseq}->{$recstart}->{$recend} = $recattr;
		$reclinenum++;
	}
	my $result = {};
	foreach my $recseq( keys %{$cache} ) {
		foreach my $recstart( sort { $a <=> $b } keys %{$cache->{$recseq}} ) {
			foreach my $recend( sort { $a <=> $b } keys %{$cache->{$recseq}->{$recstart}} ) {
				if( !defined( $result->{$recseq} ) ) {
					$result->{$recseq} = [];
				}
				push @{$result->{$recseq}}, { "start" => $recstart, "end" => $recend, "attributes" => $cache->{$recseq}->{$recstart}->{$recend} };
			}
		}
	}
	return $result;
}

my( $arg_subject, $arg_query, $arg_result ) = @ARGV;
if( !defined( $arg_subject ) || ( $arg_subject eq "" ) || !defined( $arg_query ) || ( $arg_query eq "" ) ) {
	die
"Find BED entries by coordinate in other BED entries.

Usage: $0 <subject_bed> <query_bed> [result_bed=/dev/stdout]

subject_bed	A BED file used as reference, its extra fields will kept in the result BED.
query_bed	A BED file used as query, its extra fields will ignored, only use its coordinates.
result_bed	Optional, a BED file where results writes to. If not set or set to \"-\", will write to standard output.

NOTE: If a query entry is acrossing multiple subject entries, it will break into these entries, with unmatched regions discarded.
";
}
if( !defined( $arg_result ) || $arg_result eq "" || $arg_result eq "-" ) {
	$arg_result = "/dev/stdout";
}

open my $fd_subject, "<", $arg_subject or die "Error: Cannot read file \"$arg_subject\": $!\n";
open my $fd_query, "<", $arg_query or die "Error: Cannot read file \"$arg_query\": $!\n";
open my $fd_result, ">", $arg_result or die "Error: Cannot write file \"$arg_result\": $!\n";

chomp( my @subjects_raw = <$fd_subject> );
my $subjects = bed_read( \@subjects_raw, "subject" );
chomp( my @queries_raw = <$fd_query> );
my $queries = bed_read( \@queries_raw, "query" );

foreach my $recseq( natsort( keys %{$queries} ) ) {
	if( !defined( $subjects->{$recseq} ) ) {
		warn "Warning: Sequence \"$recseq\" in queries does not exists in subjects.\n";
		next;
	}
	my @cur_queries = @{$queries->{$recseq}};
	my @cur_subjects = @{$subjects->{$recseq}};
	my $cur_subject_index = 0;
	foreach my $cur_query( @cur_queries ) {
		my $cur_query_start = $cur_query->{start};
		my $cur_query_end = $cur_query->{end};
		while( $cur_subject_index <= $#cur_subjects && $cur_subjects[$cur_subject_index]->{end} <= $cur_query_start ) {
			$cur_subject_index++;
		}
		last if $cur_subject_index > $#cur_subjects;
		my $temp_index = $cur_subject_index;
		while( $temp_index <= $#cur_subjects && $cur_subjects[$temp_index]->{start} < $cur_query_end ) {
			my $subject = $cur_subjects[$temp_index];
			my $cur_subject_start = $subject->{start};
			my $cur_subject_end = $subject->{end};
			my $cur_overlap_start = $cur_query_start > $cur_subject_start ? $cur_query_start : $cur_subject_start;
			my $cur_overlap_end = $cur_query_end < $cur_subject_end ? $cur_query_end : $cur_subject_end;
			if( $cur_overlap_start < $cur_overlap_end ) {
				print $fd_result join( "\t", $recseq, $cur_overlap_start, $cur_overlap_end, $subject->{attributes} ) . "\n";
			}
			$temp_index++;
		}
	}
}

close $fd_result;
close $fd_query;
close $fd_subject;
