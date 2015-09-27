
#echo "$1 $ $r $("

#ensure_persistent_container [target container name] [source container tag] [path to export]
ensure_persistent_container() 
{ 
	if [ -n  "$(docker ps -a | grep $1)" ] 
	  then  
	  docker create --name $1 $2 -v $3
 	fi
}

find_compose_line() 
{ 
	grep -s $1 $2 | grep -v ^# 
}

#reset_persistent_container [target container name] [source container tag] [path to export]
reset_persistent_container() 
{ 
	if [ -n  "$(docker ps -a | grep $1)" ] 
	  then  
	  echo "persistent_container $1 exists, deleting ... "
	  docker rm $(docker ps -a | grep $1 | awk '{print $1}')
	fi
	#create a persistent store for the $3 directory in the unioning file system
	echo "creating persistent_container $1 from $2 exporting the $3 directory."
	docker create -v $3 --name $1 $2
}

read_compose_spec()
{
	local containerFile=$containerDir"/compose"
	run_container=$containerDir"/run_container.sh"

	if [ -f $containerFile ] ; then
		echo "using $containerFile"
	else
		echo "$containerFile not found, exiting"
		exit -1 
	fi
	container_name="$(find_compose_line "name:" $containerFile | awk '{print $2}')"
	container_tag="$(find_compose_line "name:" $containerFile | awk '{print $3}')"
	container_ports="$(find_compose_line "ports:" $containerFile | awk '{print $2}')"
	local container_working_dir="$(find_compose_line "working_dir:" $containerFile | awk '{print $2}')"
	container_working_dir_spec=""
	if [ -n "$container_working_dir" ]
		then
		container_working_dir_spec="-w $container_working_dir"
	fi

	persistent_volume_name="$(find_compose_line "persistent_volume: " $containerFile | awk '{print $2}')"
	persistent_volume_spec=""
	if [ -n "$persistent_volume_name" ]
		then
		persistent_volume_spec="--volumes-from=$persistent_volume_name"
	fi
	persistent_container_tag="$(grep -s "persistent_volume: $1" $containerFile | awk '{print $3}')"
	persistent_container_dir="$(grep -s "persistent_volume: $1" $containerFile | awk '{print $4}')"
	volume_specs=""
	for a in 5 6 7 8 9
	do
		awkFetch="'{""print $""$a""}'"
		#echo $awkFetch
		local volume_spec="$(find_compose_line "persistent_volume $persistent_volume_name" $containerFile | eval "awk $awkFetch")"
		if [ -n "$volume_spec" ] 
			then
			 volume_specs=$volume_specs" -v $volume_spec" 
		fi
	done

	for a in 2 3 4 5 6 7 8 9
	do
		awkFetch="'{""print $""$a""}'"
		local volume_spec="$(find_compose_line "mounts: " $containerFile | eval "awk $awkFetch")"
		if [ -n "$volume_spec" ] 
			then
			 volume_specs=$volume_specs" -v $volume_spec" 
		fi
	done

	link_specs=""
	for a in 2 3 4 5 6
	do
		awkFetch="'{""print $""$a""}'"
		#echo $awkFetch
		local link_spec="$(find_compose_line "links: " $containerFile | eval "awk $awkFetch")"
		if [ -n "$link_spec" ] 
			then
			 link_specs=$link_specs" --link $link_spec" 
		fi
	done
#	echo "link_specs=$link_specs"
#	echo "container_working_dir_spec=$container_working_dir_spec"
#	exit -1
}

is_container_running()
{
	if [ -n "$(docker ps | grep $1)" ] ; then
		true
	else
		false
	fi
}

does_container_exist()
{
	if [ -n "$(docker ps -a | grep $1)" ] ; then
		true
	else
		false
	fi
}

connect_container()
{
	init_system $1

	echo "docker run -t -i -p $container_ports $volume_specs $persistent_volume_spec $link_specs $container_working_dir_spec $container_tag /bin/bash"
	echo "expected run command: $run_container in $container_working_dir_spec"

	docker run -t -i -p $container_ports $volume_specs $persistent_volume_spec $link_specs $container_working_dir_spec  $container_tag /bin/bash
}

init_system()
{
	if [ -z $container_name ]; then
		containerDir=$(pwd)"/$1"
		read_compose_spec
		if [ -z $container_name ]; then
			echo "container not specified, exiting"
			exit -1
		fi
	fi
 }

run_container()
{
	if (does_container_exist $container_name) && !(is_container_running $container_name); then
		docker start $container_name
		sleep 7s
		if  !(is_container_running $container_name) ; then
			echo "failed to start $container_name"
		fi
	fi

	if  !(is_container_running $container_name) ; then
		echo "attempting to run $container_name"
		if (does_container_exist $container_name) ; then
			docker logs -t $container_name
			echo "docker commit -m \"Commit of $container_tag after failure\" $containerId $container_tag" 
			docker commit -m "Commit of $container_tag after failure" $containerId $container_tag
			docker rm $container_name
		fi
		echo "docker run -td -p $container_ports $volume_specs $persistent_volume_spec $link_specs $container_working_dir_spec --name=$container_name $container_tag /bin/bash $run_container"
		docker run -td -p $container_ports $volume_specs $persistent_volume_spec $link_specs $container_working_dir_spec --name=$container_name $container_tag /bin/bash $run_container
		sleep 7s
		if  !(is_container_running $container_name) ; then
			echo "$container_name exists, and failed to start ... logging you in"
			connect_container
		fi
	fi	
}

stop_container()
{
	init_system $1
    echo "attempting to stop $container_name"
	docker stop $container_name
}

logs()
{
	init_system $1
    echo "attempting to get logs from $container_name"
	docker logs -t $container_name
}

start_container()
{
	init_system $1
    echo "attempting to start $container_name"
	#if container is running already, just return
	if  is_container_running $container_name ; then
		echo "$container_name is already running"
		return 1
	elif  does_container_exist $container_name ; then
		echo "$container_name exists, but is not running ... starting"
		run_container
	else
		local init_container=$containerDir"/init_container.sh"
		echo "$1 doesnt exist, creating."
		echo "docker build -t=\"$container_tag\" $containerDir"
		docker build -t=\"$container_tag\" $containerDir
		
		echo "docker run -p $container_ports $volume_specs $persistent_volume_spec $container_tag /bin/bash $init_container"
		docker run -p $container_ports $volume_specs $persistent_volume_spec $container_tag /bin/bash $init_container
		local containerId=$(docker ps -l | sed -n 2p | awk '{print $1}')

		echo "docker commit -m \"First reset of $container_tag\" $containerId $container_tag" 
		docker commit -m "First reset of $container_tag" $containerId $container_tag 

		run_container
	fi
}

reset_container()
{
	if  is_container_running $container_name ; then
		echo "$1 is already running, stopping ... "
		docker stop $container_name
	fi
	if  does_container_exist $container_name ; then
		docker rm $container_name
	fi
	reset_persistent_container $persistent_volume_name $persistent_container_tag $persistent_container_dir
	start_container $container_name $container_ports 

}

ensure_compose_exists()
{
	if [ ! -f /usr/local/bin/docker-compose ] ; then
		curl -L https://github.com/docker/compose/releases/download/1.1.0/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
		chmod +x /usr/local/bin/docker-compose
	fi
}


#docker inspect  --format '{{ .NetworkSettings.IPAddress }}' mariadb_herolab
containerDir="/stacks/$1"
read_compose_spec
#reset_container mariadb_herolab "3306:3306" mariadb/herolab
#start_container mariadb_herolab
#ensure_compose_exists

if [ -d $containerDir ] && [ -n $containerDir ] ; then
	echo "Container Dir: $containerDir found doing $2 $3 $4 $5 ..."
	$2 $3 $4 $5
else
	echo "$containerDir does not exist, exiting ..." 
	exit -1
fi

#cane 
#cabin creates the main server
#stack is a configuration for a container or set of containers
#stacker is a
