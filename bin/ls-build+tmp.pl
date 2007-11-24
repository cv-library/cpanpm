use strict;
use warnings;

my @all;
for my $dir (qw(/tmp /home/sand/.cpan/build /home/k/.cpan/build)) {
  opendir my $dh, $dir or die "Couldn't opendir: $!";
  push @all, map { "$dir/$_" } readdir $dh;
}
my @rall = sort { $a->[1] <=> $b->[1] }
    map { [$_, (stat$_)[9]] } @all;
my @lookback;
DIRENT: for my $dirent (@rall) {
  push @lookback, $dirent;
  if ($dirent->[0] eq $rall[-1][0] || @lookback>=3) {
    if (
        $lookback[-3][0] =~ m|^/tmp|
       ) {
      if (
          $lookback[0][0] !~ m|^/tmp|
          &&
          $lookback[1][0] !~ m|^/tmp|
          &&
          $lookback[-2][0] !~ m|^/tmp|
          &&
          $lookback[-1][0] !~ m|^/tmp|
         ) {
        shift @lookback while $lookback[2][0] !~ m|^/tmp|;
        while (my $de = shift @lookback) {
          my @t = localtime($de->[1]);
          $t[5]+=1900;
          $t[4]++;
          my $sigil = -d $de->[0] ? "/" : "";
          printf "%04d-%02d-%02dT%02d:%02d:%02d %s%s\n", @t[5,4,3,2,1,0], $de->[0], $sigil;
        }
        print "---\n";
      } else {
        next DIRENT;
      }
    }
  }
  shift @lookback if @lookback > 5;
}
