#! /usr/bin/perl
my( $clstrfile, $prefix ) = @ARGV;
if( ( $clstrfile eq '' ) || ( $prefix eq '' ) ) {
	die( "Get members of each cluster from CD-HIT's clstr file.\n\nUsage: $0 <clstr_file> <output_prefix>\n\nclstr_file\tThe .clstr result file from CD-HIT.\noutput_prefix\tThe prefix of output files. Example: Use \"tmp/\" when output files are aimed stored under \"tmp\" directory.\n" );
}
my $init = 0;
my $cluster = '';
open CTRFD, "<$clstrfile";
chomp( @source = <CTRFD> );
close CTRFD;
foreach $recline( @source ){
	if( $recline =~ /^>Cluster\s*(\d+)/ ) {
		$cluster = $1;
		if( $init = 1 ) {
			close DSTFD;
		}
		$init = 1;
		open DSTFD, ">${prefix}Cluster${cluster}.list";
	} else {
		if( $cluster ne '' ) {
			if( $recline =~ /^\d+\s+\d+aa,\s+>(.+?)\.\.\.\s+(?:\*|at [\d\.]+%)$/ ) {
				print DSTFD "$1\n";
			}
		}
	}
}
close DSTFD;
