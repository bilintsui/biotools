#! /usr/bin/perl
my( $srcFile, $dstPrefix, $clusterMinSize, $baseUpstream, $baseDownstream ) = @ARGV;
if( $srcFile eq '' || $dstPrefix eq '' ) {
	die( "Split CD-HIT clusters, and convert to BED file.\n\nUsage: $0 <clstr_file> <output_prefix> [min_size] [base_upstream] [base_downstream]\n\nclstr_file\tCD-HIT's clstr file, used as source file.\noutput_prefix\tPrefix of splitted cluster outputs to.\nmin_size\tMinimum size of clusters to be outputted. If the cluster is smaller than this, that will not be outputted. When omitted or set to 0, means output all.\nbase_upstream\tBase numbers which needs to be expanded from the range start. Default: 0\nbase_downstream\tBase numbers which needs to be expanded from the range end. Default: 0\n\nNOTE\n\tThis script will split forward and reverse matched sequences to separate files.\n\tThe sequence ID in clstr file must be: <orig_seqid>:<range1>-<range2>\n" );
}
if( $clusterMinSize == 0 ) {
	$clusterMinSize = '';
}
if( $baseUpstream eq '' ) {
	$baseUpstream = 0;
}
if( $baseDownstream eq '' ) {
	$baseDownstream = 0;
}
my @cache = ();
my @cache = ();
my $curClusters = 0;
open SRCFD, "<$srcFile";
foreach $recline( <SRCFD> ) {
	chomp( $recline );
	if( $recline =~ /^>Cluster\s*(\d+)$/ ) {
		$curClusters++;
		$cache[ $curClusters - 1 ]->{name} = "Cluster$1";
		$cache[ $curClusters - 1 ]->{data} = ();
	}
	if( $recline =~ /^\d+\s+\d+aa,\s+>(.+):(\d+)-(\d+)...\s+(?:\*|at\s+[\d\.]+%)$/ ) {
		my $item;
		$item->{seqID} = $1;
		$item->{start} = $2;
		$item->{end} = $3;
		push @{$cache[ $curClusters - 1 ]->{data}}, $item;
	}
}
foreach $recCache( @cache ) {
	my @curData = @{$recCache->{data}};
	if( ( $clusterMinSize eq '' ) || ( $clusterMinSize ne '' && ( $#curData + 1 ) >= $clusterMinSize ) ) {
		my @outForward = ();
		my @outReverse = ();
		foreach $curItemRaw( @curData ) {
			my $curItem = $curItemRaw;
			if( $curItem->{start} < $curItem->{end} ) {
				$curItem->{start} = $curItem->{start} - $baseUpstream - 1;
				$curItem->{end} = $curItem->{end} + $baseDownstream;
				push @outForward, $curItem;
			} elsif ( $curItem->{start} > $curItem->{end} ) {
				my $newStart = $curItem->{end} - $baseUpstream - 1;
				my $newEnd = $curItem->{start} + $baseDownstream;
				$curItem->{start} = $newStart;
				$curItem->{end} = $newEnd;
				push @outReverse, $curItem;
			}
		}
		if( $#outForward >= 0 ) {
			open DSTFD, ">$dstPrefix" . $recCache->{name} . "-forward.bed";
			foreach $recRecord( @outForward ) {
				print DSTFD $recRecord->{seqID} . "\t" . $recRecord->{start} . "\t" . $recRecord->{end} . "\n";
			}
			close DSTFD;
		}
		if( $#outReverse >= 0 ) {
			open DSTFD, ">$dstPrefix" . $recCache->{name} . "-reverse.bed";
			foreach $recRecord( @outReverse ) {
				print DSTFD $recRecord->{seqID} . "\t" . $recRecord->{start} . "\t" . $recRecord->{end} . "\n";
			}
			close DSTFD;
		}
	}
}
