package overlayfs;
use Exporter qw(import);
our @ISA = qw(Exporter);
our @EXPORT = qw(stack_new_layer create_and_mount_layer get_greatest_layer get_current_layer get_all_layers bring_layer_to_front get_base_dir delete_all_layers);

$layers_dir=($ENV{'LAYERS_DIR'})?($ENV{'LAYERS_DIR'}):("/root/layers");
if(! -d $layers_dir)
{
        mkdir("$layers_dir") or die("failed to mkdir $layers_dir :: $!\n");
}

chomp($pwd = `pwd`);


sub bring_layer_to_front
{
	my($original_dir,$layer_tag)=@_;

	my $existing_layers = &get_current_lower_dirs;
	my $remountable_layer,$remountable_layer_number;
	
	if( -l "$layers_dir/$layer_tag")
	{
		$remountable_layer = readlink("$layers_dir/$layer_tag");
		$remountable_layer =~ /\/([^\/]+)$/;
	        $remountable_layer_number = $1;
	}
	else
	{
		$remountable_layer = "$layers_dir/$layer_tag";
		$remountable_layer_number = $layer_tag;
	}

	print "\$remountable_layer = $remountable_layer\n\$remountable_layer_number = $remountable_layer_number\n";
	
	my %all_layers_hash = get_all_layers();
	@all_layers = values(%all_layers_hash);


	if($all_layers[$#all_layers] eq $layer_tag)
        {
                print "latest layer on top\n";
                return;
        }


	 %all_lower_dirs = get_all_lower_dirs();


	#unmount all layers and prepare for re-layering
	#chdir('/root/');
	if($pwd eq $original_dir)
	{
		print "PWD IS : ".`pwd`."\nPlease exit the working directory and then unmount.\nExiting...\n";
		exit;
	}

	for(0..$#all_layers)
	{
		#print "#########".$all_layers[$i++]."#########\n";
		$unmount_older_mount_cmd = "umount $original_dir";
		#$unmount_older_mount_cmd = "fuser -vm $original_dir";
               	print "$unmount_older_mount_cmd\n";
               	system("$unmount_older_mount_cmd");
	}

	
	foreach(sort(keys(%all_lower_dirs)))
	{
		print "\$_ = $_\n";
		if($_ ne $remountable_layer_number)
		{
			print "$_ != $remountable_layer_number\n";
			my $remount_layer_cmd = "mount -t overlay $_ -o $all_lower_dirs{$_} $original_dir";
	                print "$remount_layer_cmd\n";
	                system("$remount_layer_cmd");
		}
	}
        my $remount_layer_cmd = "mount -t overlay $remountable_layer_number -o $all_lower_dirs{$remountable_layer_number} $original_dir";
	print "$remount_layer_cmd\n";
        system("$remount_layer_cmd");


#		$unmount_older_mount_cmd = "umount $layer_tag";
#		print "\$unmount_older_mount_cmd = $unmount_older_mount_cmd\n";
#		system($unmount_older_mount_cmd);
#		$remount_layer_cmd = "mount -t overlay $layer_number -o lowerdir=$remountable_layer:$existing_layers,upperdir=$remountable_layer,workdir=$layers_dir/merged $original_dir";
#	        print "$remount_layer_cmd\n";
#	        system($remount_layer_cmd);


}

sub stack_new_layer
{
	my($original_dir,$new_upper_layer,$layer_tag)=@_;

	$new_upper_layer =~ /\/([^\/]+)$/;
	my $layer_number = $1;
	print "\$layer_number = $layer_number\n";
	print "\$layer_tag = $layer_tag\n";
	
	$create_layer_cmd = "mkdir $new_upper_layer";
        print "$create_layer_cmd\n";
        system($create_layer_cmd);

        $tag_empty_layer_cmd="ln -s $new_upper_layer $layers_dir/$layer_tag" if ($layer_tag ne $layer_number);
        print "$tag_empty_layer_cmd\n";
        system($tag_empty_layer_cmd);

	$existing_layers = &get_current_lower_dirs;
	print "\$existing_layers = $existing_layers\n";

	if(! $existing_layers)
	{
		$existing_layers = $original_dir;
	}
	elsif($existing_layers =~ /$original_dir/)
	{
		$existing_layers =~ s/:$original_dir//g;
	}

	$stack_layer_cmd = "mount -t overlay $layer_number -o lowerdir=$new_upper_layer:$existing_layers,upperdir=$new_upper_layer,workdir=$layers_dir/merged $original_dir";
	print "$stack_layer_cmd\n";
        system($stack_layer_cmd);

	#mount -t overlay 002 -o lowerdir=/root/layers/002:/root/layers/001:/root/layers/000 /root/d1
}

sub create_and_mount_layer
{
	my($lower_layer,$upper_layer,$layer_tag)=@_;
	$create_layer_cmd = "mkdir $upper_layer";
	print "$create_layer_cmd\n";
	system($create_layer_cmd);

	$initialize_empty_layer_cmd="touch $upper_layer/.$layer_tag";
	print "$initialize_empty_layer_cmd\n";
	system($initialize_empty_layer_cmd);
	
	$mount_layer_cmd = "mount -t overlay $layer_tag -o lowerdir=$lower_layer,upperdir=$upper_layer,workdir=$layers_dir/merged $lower_layer";
	print "$mount_layer_cmd\n";
	system($mount_layer_cmd);
}

sub get_base_dir
{
	my $base_dir = `mount | grep overlay | head -1 | cut -d' ' -f3`;
        if ((-d $base_dir) && ($base_dir !~ /layer/))
        {
                return($base_dir);
        }
}

sub get_current_lower_dirs
{
	my $all_lower_layers = `mount | grep overlay 2>&1 | tail -1 | cut -d' ' -f 6`;
        #(rw,relatime,seclabel,lowerdir=/root/d1:/root/layers/000:/root/layers/001
	if($all_lower_layers)
	{
		$all_lower_layers =~ /lowerdir=([^(),]+)[),]/;
		return($1);
	}
}

sub get_all_lower_dirs
{
	my @all_lower_layers = `mount | grep overlay 2>&1 | cut -d' ' -f 1,6`;
        chomp(@all_lower_layers);
	foreach(@all_lower_layers)
	{
		$_ =~ s/(\w+,)+lowerdir/lowerdir/;
		$_ =~ s/\(+//;
		$_ =~ s/\)+//;
		$_ =~ /([^\s]+)\s+([^\s]+)/;
		$all_lower_layers_info{$1}=$2;
	}
	return(%all_lower_layers_info);
}

sub get_current_layer
{
	my($working_dir)=@_;
	chomp($current_layer = `df -kh $working_dir --output=source | tail -1`);
	return($current_layer);
}

sub get_greatest_layer
{
        my @all_layers = `mount | grep overlay 2>&1 | cut -d' ' -f 1`;
        chomp(@all_layers = sort @all_layers);
        #print "\@all_layers = @all_layers\n";
        #print $all_layers[$#all_layers];
        #exit;
        return($all_layers[$#all_layers]);
}

sub get_all_layers
{
	my @all_layers = `mount | grep overlay 2>&1 | cut -d' ' -f 1`;
        chomp(@all_layers = @all_layers);
        #print "\@all_layers = @all_layers\n";
	@all_layer_content = <$layers_dir/*>;

	foreach my $tag_symlink(get_all_layer_tags())
	{
		my $symlink_target = readlink("$layers_dir/$tag_symlink");
                #print "$layers_dir/$tag_symlink -> $symlink_target\n";
		
                if($symlink_target eq "$layers_dir/".$all_layers[$#all_layers])
                {
          		$all_layers_hash{$tag_symlink} = "$symlink_target";
                }
                else
                {
                       	$all_layers_hash{$tag_symlink} = "$symlink_target";
                }
		push(@done,$tag_symlink,$symlink_target);
	}

	my @layer_dir_contents = <$layers_dir/*>;
	chomp(@layer_dir_contents);

	foreach my $dir(@layer_dir_contents)
	{
		
		$dir =~ /\/([^\/]+)$/;
		$dir_basename = $1;
		next if ($dir_basename eq 'merged');
		if(grep /$dir_basename/, @done)
		{
			next;
		}
		
		$all_layers_hash{$dir_basename}="$layers_dir/$dir_basename";
		
	}

	return(%all_layers_hash);
}

sub get_all_layer_tags
{
	opendir(LAYERS,"$layers_dir") or die("failed to open dir $layers_dir :: $!\n");
	my @dir_contents = readdir(LAYERS);
	close(LAYERS);

	foreach(@dir_contents)
	{
		if(-l ("$layers_dir/$_"))
		{
			#print "$layers_dir/$_ -> ".readlink("$layers_dir/$_")."\n";
			push(@all_layer_tags,"$_");
		}
	}
	return(@all_layer_tags);
}

sub delete_all_layers
{
	my($original_dir,$layer_tag)=@_;
	my %all_layers_hash = get_all_layers();
	my %all_lower_dirs = get_all_lower_dirs();
	my $current_layer = get_current_layer($original_dir);
	if(-l ("$layers_dir/$layer_tag"))
        {
        	#print "$layers_dir/$_ -> ".readlink("$layers_dir/$_")."\n";
        	#push(@all_layer_tags,"$_");
		if(readlink("$layers_dir/$layer_tag") =~ /\/([^\/]+)$/)
		{
			$layer_basename = $1;
			print "\$layer_basename = $layer_basename\n";
			#exit;
		}
	}
	else
        {
        	$layer_basename = $layer_tag;
        }                

	if($pwd eq $original_dir)
        {
                print "PWD IS : ".`pwd`."\nPlease exit the working directory and then unmount.\nExiting...\n";
                exit;
        }

	foreach(keys(%all_layers_hash))
	{
		#print "#########".$all_layers[$i++]."#########\n";
		$unmount_older_mount_cmd = "umount $original_dir";
		#$unmount_older_mount_cmd = "fuser -vm $original_dir";
		print "$unmount_older_mount_cmd\n";
		system("$unmount_older_mount_cmd");
		$delete_layer_dir_cmd = "rm -rf $all_layers_hash{$_}";
		if(($layer_tag) && ($layer_tag eq $_))
		{
			print "deleting $layer_tag\n";
			print "$delete_layer_dir_cmd\n";
			system($delete_layer_dir_cmd);
			next;
		}
		elsif(! $layer_tag)
		{
			print "deleting $all_layers_hash{$_}\n";
			print "$delete_layer_dir_cmd\n";
			system($delete_layer_dir_cmd);
		}
	}
	return if (! $layer_tag);
	foreach(sort(keys(%all_lower_dirs)))
        {
                print "\$_ = $_\n";
                if(($_ ne $layer_basename) && ($_ ne $current_layer))
                {
                        print "$_ != $layer_basename\n";
			$layer_details = $all_lower_dirs{$_};
			$layer_details =~ s/$layers_dir\/$layer_tag://;
                        my $remount_layer_cmd = "mount -t overlay $_ -o $layer_details $original_dir";
                        print "$remount_layer_cmd\n";
                        system("$remount_layer_cmd");
                }
        }
	if($layer_tag ne $current_layer)
	{
		my $remount_layer_cmd = "mount -t overlay $current_layer -o $all_lower_dirs{$current_layer} $original_dir";
        	print "$remount_layer_cmd\n";
		system("$remount_layer_cmd");
	}
}

1;
