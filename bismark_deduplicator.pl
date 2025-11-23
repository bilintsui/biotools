#! /usr/bin/perl
use Sort::Key::Natural qw(natsort);
if( ! @ARGV ) {
	die( "Keep only one name within the same location in bismark results.\n\nUsage: $0 <bismark_result1> [bismark_result2] ...\n" );
}
my $cache;
my $header = '';
foreach $recfile( @ARGV ) {
	open SRCFD, "<${recfile}" or die( "Error: Cannot read file \"${recfile}\".\n" );
	close SRCFD;
}
foreach $recfile( @ARGV ) {
	open SRCFD, "<${recfile}";
	print STDERR "Reading \"${recfile}\" ...\n";
	chomp( my @sources = <SRCFD> );
	close SRCFD;
	print STDERR "Processing \"${recfile}\" ...\n";
	$header = shift @sources;
	while( @sources ) {
		my $recline = shift @sources;
		my( $field_readsname, $field_strand, $field_seqname, $field_location, $field_methylation ) = split /\t/, $recline;
		my $record_name = "${field_seqname}\t${field_location}\t${field_methylation}\t${field_strand}";
		if( ! $cache->{$record_name} ) {
			@{$cache->{$record_name}} = ();
		}
		push @{$cache->{$record_name}}, $field_readsname;
	}
}
print STDERR "Sorting keys ...\n";
my @keys = natsort keys %{$cache};
print STDERR "Outputting ...\n";
print "${header}\n";
foreach $reckey( @keys ) {
	my @sorted = natsort @{$cache->{$reckey}};
	my( $final_seqname, $final_location, $final_methylation, $final_strand ) = split /\t/, $reckey;
	print "$sorted[ 0 ]\t$final_strand\t$final_seqname\t$final_location\t$final_methylation\n";
}
