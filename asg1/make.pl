#!/usr/bin/perl
# Author: Adam Henry, adlhenry@ucsc.edu
# $Id: make.pl,v 1.9 2014-10-19 19:56:00-07 - - $
use strict;
use warnings;
use Getopt::Std;

$0 =~ s/^.\///;
my $exit_status = 0;
END {exit $exit_status}

# Linux 2.6.32-431.29.2.el6.x86_64 x86_64
my %strsignal = (
    0 => "Unknown signal 0",
    1 => "Hangup",
    2 => "Interrupt",
    3 => "Quit",
    4 => "Illegal instruction",
    5 => "Trace/breakpoint trap",
    6 => "Aborted",
    7 => "Bus error",
    8 => "Floating point exception",
    9 => "Killed",
   10 => "User defined signal 1",
   11 => "Segmentation fault",
   12 => "User defined signal 2",
   13 => "Broken pipe",
   14 => "Alarm clock",
   15 => "Terminated",
   16 => "Stack fault",
   17 => "Child exited",
   18 => "Continued",
   19 => "Stopped (signal)",
   20 => "Stopped",
   21 => "Stopped (tty input)",
   22 => "Stopped (tty output)",
   23 => "Urgent I/O condition",
   24 => "CPU time limit exceeded",
   25 => "File size limit exceeded",
   26 => "Virtual timer expired",
   27 => "Profiling timer expired",
   28 => "Window changed",
   29 => "I/O possible",
   30 => "Power failure",
   31 => "Bad system call",
   32 => "Unknown signal 32",
   33 => "Unknown signal 33",
   34 => "Real-time signal 0",
   35 => "Real-time signal 1",
   36 => "Real-time signal 2",
   37 => "Real-time signal 3",
   38 => "Real-time signal 4",
   39 => "Real-time signal 5",
   40 => "Real-time signal 6",
   41 => "Real-time signal 7",
   42 => "Real-time signal 8",
   43 => "Real-time signal 9",
   44 => "Real-time signal 10",
   45 => "Real-time signal 11",
   46 => "Real-time signal 12",
   47 => "Real-time signal 13",
   48 => "Real-time signal 14",
   49 => "Real-time signal 15",
   50 => "Real-time signal 16",
   51 => "Real-time signal 17",
   52 => "Real-time signal 18",
   53 => "Real-time signal 19",
   54 => "Real-time signal 20",
   55 => "Real-time signal 21",
   56 => "Real-time signal 22",
   57 => "Real-time signal 23",
   58 => "Real-time signal 24",
   59 => "Real-time signal 25",
   60 => "Real-time signal 26",
   61 => "Real-time signal 27",
   62 => "Real-time signal 28",
   63 => "Real-time signal 29",
   64 => "Real-time signal 30",
);

# Define hash tables.
my %macros;
my %targets;

# Collect the user options.
my %options;
getopts ('dnf:', \%options);

# Record target hierarchy.
my @target_array;

# Populates the macro table.
sub macro_hash {
  for (keys %macros) {
    while ($macros{$_} =~ s/\$\{([^}]+)\}/$macros{$1}/) {
    }
    $macros{$_} =~ s/^\s+|\s+$|\s{2,}|#(.*)//g;
    $macros{$_} =~ s|\$\$|\$|g;
  }
}

# Macro-swaps the target table.
sub macro_swap {
  for my $trgt (keys %targets) {
    $_ = $targets{$trgt}{'deps'};
    my @deps;
    if (defined) {
      while (s/\$\{([^}]+)\}/$macros{$1}/) {
      }
      @deps = split;
    }
    $targets{$trgt}{'deps'} = \@deps;
    for (@{$targets{$trgt}{'cmds'}}) {
      while ($_ =~ s/\$\{([^}]+)\}/$macros{$1}/) {
      }
      $_ =~ s|\$\$|\$|g;
    }
  }
}

# Return file modification time.
sub mtime {
  my @filestat = stat $_[0];
  return $filestat[9];
}

# Execute target commands.
sub exe_cmds {
  my ($trgt, $t_name) = @_;
  $trgt =~ s/%/$t_name/;
  my $dep1 = ${$targets{$_[0]}{'deps'}}[0];
  $dep1 =~ s/%/$t_name/ if defined $dep1;
  for (@{$targets{$_[0]}{'cmds'}}) {
    my $cmd_line = $_;
    my $exit_ignore = 0;
    if ($cmd_line =~ s/^-\s//) {
      $exit_ignore = 1;
    }
    $cmd_line =~ s/\$</$dep1/g;
    $cmd_line =~ s/\$@/$trgt/g;
    print "$cmd_line\n";
    system ($cmd_line) if not defined $options{'n'};
    my $term_signal = $? & 0x7F;
    my $core_dumped = $? & 0x80;
    my $exit_stat = ($? >> 8) & 0xFF;
    if ($exit_stat != 0) {
      printf "%s: %s[%s] Error %d%s\n", $0, 
      $exit_ignore ? '' : '*** ', $trgt, 
      $exit_stat, $exit_ignore ? ' (ignored)' : '';
      if (!$exit_ignore) {
        exit 2;
      } else {
        $exit_status = $exit_stat;
      }
    }
  }
}

# Seek wild-card targets.
sub pre_build {
  my $trgt = $_[0];
  my @trgt_def = split /\./;
  my $t_name = $trgt_def[0];
  my $trgt_ext = $trgt_def[1];
  for (@target_array) {
    if ($_ eq $trgt) {
      target_build ($_, $t_name);
      return;
    }
    if (defined $trgt_ext && $_ eq "%.$trgt_ext") {
      target_build ("%.$trgt_ext", $t_name);
      return;
    }
  }
}

# Make a target.
sub target_build {
  my $exe = 0;
  my ($trgt, $t_name) = @_;
  $trgt =~ s/%/$t_name/;
  my $t_mtime = mtime ($trgt);
  if (not defined $t_mtime) {
    $exe = 1;
    $t_mtime = 0;
    if (defined $options{'d'}) {
      print "$trgt: file does not exist, rebuild $trgt\n";
    }
  }
  for (@{$targets{$_[0]}{'deps'}}) {
    my $dep = $_;
    $dep =~ s/%/$t_name/;
    my $d_mtime = mtime ($dep);
    if (not defined $d_mtime) {
      pre_build ($dep);
      next;
    }
    if ($t_mtime != 0 && $t_mtime < $d_mtime) {
      $exe = 1;
      if (defined $options{'d'}) {
        print "$trgt: file is obsolete with dependenency $dep, 
        rebuild $trgt\n";
      }
    }
  }
  exe_cmds ($_[0], $t_name) if $exe == 1;
}

# Set the makefile.
my $makefile = './Makefile';
$makefile = $options{'f'} if defined $options{'f'};

# Extract the macro table.
open (my $mfile, "<", "$makefile") or die "$makefile: $!";
while (<$mfile>) {
  if (/(^[A-Z]+)\s*=/) {
    chomp;
    my @macrodef = split /\s*=\s*/;
    $macros{$1} = $macrodef[1];
  }
}
close $mfile;

# Populate the macro table.
macro_hash();

# Extract the target table.
open ($mfile, "<", "$makefile") or die "$makefile: $!";
my $cmds_ref;
while (<$mfile>) {
  next if (/^#|^ifeq|^endif|^include|^[A-Z]/);
  # Command line.
  if (/^\t/) {
    $_ =~ s/\t|\n//g;
    push (@$cmds_ref, $_);
    next;
  }
  # Target specification.
  if (/(\S+)\s*:/) {
    chomp;
    my @cmds;
    $cmds_ref = \@cmds;
    my @depsdef = split /\s*:\s*/;
    my $deps = $depsdef[1];
    my $p = {'deps' => $deps, 'cmds' => $cmds_ref};
    my $trgt = $1;
    $trgt =~ s/\$\{([^}]+)\}/$macros{$1}/;
    if (not defined $targets{$trgt}) {
      $targets{$trgt} = $p;
      push (@target_array, $trgt);
    } elsif ($targets{$trgt}{'deps'} eq $deps) {
        $targets{$trgt}{'cmds'} = $cmds_ref;
    }
  }
}
close $mfile;

# Macro-swap the target table.
macro_swap();

# Execute specified targets.
$ARGV[0] = $target_array[0] if not defined $ARGV[0];
for (@ARGV) {
  pre_build ($_);
}

sub debug_print {
    # Print macro hash table
    print "\n====== MACROS ======\n";
    print "$_ = $macros{$_}\n" for keys %macros;

    # Print target entries.
    print "\n====== TARGETS =======\n";
    for my $trgt (keys %targets) {
      print "\n$trgt :";
      print " $_" for @{$targets{$trgt}{'deps'}};
      print "\n";
      print "\t$_\n" for @{$targets{$trgt}{'cmds'}};
    }
}

# debug_print() if defined $options{'d'};