#!/usr/local/bin/perl

=head1 NAME 

load_seqdatabase.pl

=head1 SYNOPSIS

   load_seqdatabase.pl -host somewhere.edu -sqldb bioperl -format swiss \
     swiss_sptrembl swiss.dat primate.dat 

=head1 DESCRIPTION

This script loads a bioperl-db with sequences. There are a number of
options to do with where the bioperl-db database is (ie, hostname,
user for database, password, database name) followed by the database
name you wish to load this into and then any number of files. The
files are assumed to be SeqIO formatted files with the format given
in the -format flag.


=head1 ARGUMENTS
   
  The last two arguments are data_title, and then the filelist.
  These are the only args that are absolutely required.
  Default values for each parameter are shown in brackets.
  (Note that -bulk is no longer available):

  -host    $URL        : the IP addy incl. port (localhost)
  -sqldb   $db_name    : the name of the sql database (bioperl_db)
  -dbuser  $username   : username (root)
  -dbpass  $password   : password (undef)
  -format  $FileFormat : format of the flat files (embl)
                       : Can be any format read by Bio::SeqIO
  -safe                : flag to ignore errors
  *data_title          : A name to associate with this data
  *file1 file2 file3...: the flatfiles to import
 

=cut



use Getopt::Long;
use Bio::DB::SQL::DBAdaptor;
use Bio::SeqIO;


my $host = "localhost";
my $sqlname = "biosql";
my $dbuser = "root";
my $driver = 'mysql';
my $dbpass = undef;
my $format = 'genbank';
my $removeflag = '';
my $transactional = 0;
#If safe is turned on, the script doesn't die because of one bad entry..
my $safe = 0;

&GetOptions( 'host:s' => \$host,
             'driver:s' => \$driver,
	     'sqldb:s'  => \$sqlname,
	     'dbuser:s' => \$dbuser,
	     'dbpass:s' => \$dbpass,
	     'format:s' => \$format,
	     'safe'     => \$safe,
	     'remove'     => \$remove,
             'transactional' => \$transactional,
	     );

my $dbname = shift;
my @files = @ARGV;

if ($safe && $transactional) {
    print <<EOM;
-safe and -transactional invalid combination

the reason is that the adaptor code caches data/ids; if a transaction fails
then the whole application must fail, otherwise we risk the cache and the
database being out of sync, which could have very bad consequences
EOM
}

if( !defined $dbname || scalar(@files) == 0 ) {
    system("perldoc $0");
    exit(0);
}

$dbadaptor = Bio::DB::SQL::DBAdaptor->new( -host => $host,
					   -dbname => $sqlname,
                                           -driver=> $driver,
					   -user => $dbuser,
					   -pass => $dbpass,
					   );

$dbid = $dbadaptor->get_BioDatabaseAdaptor->fetch_by_name_store_if_needed($dbname);
my $seqadp = $dbadaptor->get_SeqAdaptor;

foreach $file ( @files ) {

    print STDERR "Reading $file\n";
    my $seqio = Bio::SeqIO->new(-file => $file,-format => $format);

    while( $seq = $seqio->next_seq ) {
        $dbadaptor->begin_work if $transactional;
        if ($removeflag) {
            my $oldseq =
              $seqadp->remove_by_db_and_accession($dbname, $seq->accession);
        }
	if ($safe) {
	    eval {
		$seqadp->store($dbid,$seq);
	    };
	    if ($@) {
		print STDERR "Could not store ".$seq->accession." because of $@\n";
	    }
	}
	else {
	    $seqadp->store($dbid,$seq);
	}
        $dbadaptor->commit if $transactional;
    }
}

$dbadaptor->disconnect;







