#/stacker/pharaoh.sh starts the container environment and provides the files and scripts necessary for it to run, where possible files are mapped from the local system.
#/stacker contains the scripts to control the application containers
#/stacks contain configuration of each application containers
#/apps contains the binaries or scripts

ensure_aws_plugin()
{
	if [ -z "$(vagrant plugin list | grep vagrant-aws)" ] 
	  then  
	  vagrant plugin install vagrant-aws
 	fi
}

ensure_ec2_dummy_box()
{
	if [ -z "$(vagrant box list | grep dummy | grep aws)" ] 
		then  
		vagrant box add dummy https://github.com/mitchellh/vagrant-aws/raw/master/dummy.box
	fi
}
stacksDir="/Users/mike/Projects/stacks"

#vagrant plugin install vagrant-aws
vmhost()
{
	VAGRANT_CWD=`pwd`/vmhost SYNC_OUTSIDE_1="$stacksDir" SYNC_INSIDE_1='/stacks' SYNC_OUTSIDE_2='/Users/mike/Projects/stacker' SYNC_INSIDE_2='/stacker' SYNC_OUTSIDE_3='/Users/mike/Projects/stacks' SYNC_INSIDE_3='/apps' vagrant $@
}

ec2()
{
	ensure_aws_plugin
	ensure_ec2_dummy_box
	VAGRANT_CWD=`pwd`/ec2 SYNC_OUTSIDE_1="$stacksDir" SYNC_INSIDE_1='/stacks' SYNC_OUTSIDE_2='/Users/mike/Projects/stacker' SYNC_INSIDE_2='/stacker' SYNC_OUTSIDE_3='/Users/mike/Projects/stacks' SYNC_INSIDE_3='/apps' vagrant $@ 
}

$@