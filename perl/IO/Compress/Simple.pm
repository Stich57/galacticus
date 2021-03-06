# Contains a Perl module which implements useful compression tools.

package IO::Compress::Simple;
use strict;
use warnings;
use IO::Compress::Bzip2 qw(bzip2 $Bzip2Error);

sub Compress_Directory {
    # Compress all files in a directory.

    # Get the directory name.
    my $directoryName = shift;

    opendir(dirHndl,$directoryName);
    while ( my $fileName = readdir(dirHndl) ) {
	unless ( $fileName =~ m/^\./ || $fileName =~ m/\.gz$/ || $fileName =~ m/\.bz2/ ) {
	    if ( bzip2 "<".$directoryName."/".$fileName.">" => "<".$directoryName."/".$fileName.".bz2>" ) {
		unlink($directoryName."/".$fileName);
	    } else {
		print "Failed to compress ".$directoryName."/".$fileName."\n";
	    }
	}
    }
    closedir(dirHndl);
}

1;
