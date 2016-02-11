#!/bin/bash                                                                  

BP_DIR=$(pwd)
APP=$1       
CLEAR=$2

#if there is no an app argument, exit
if [ -z $APP ]                       
then                                 
        echo "Usage: $0 <app archive path>"
        exit 1                             
fi                                         


echo "Using build pack dir: $BP_DIR"
echo "Using app archive: $APP"      

#test if this is actually a build pack dir

if [ -f "$BP_DIR/bin/detect" ]
then                          
        echo "Current directory IS a valid build pack..."
else                                                     
        echo "Current directory is NOT a valid build pack..."
        exit 1;                                              
fi                                                           

#create output directories
TEMP_DIR="$BP_DIR/build/run/tmp"
APP_DIR="$BP_DIR/build/run/app" 

#check if these dirs exist
if [ ! -d $TEMP_DIR ]     
then                      
        echo "Creating build pack temp dir: $TEMP_DIR"
        mkdir -p $TEMP_DIR                            
elif [ ! -z $CLEAR ]
then
        echo "Cleaning up temp dir..."                
        rm -rf $TEMP_DIR/*                            
else
        echo "Not cleaning up the temp dir..."
fi                                                    

if [ ! -d $APP_DIR ]
then                
        echo "Creating build pack app dir: $APP_DIR"
        mkdir -p $APP_DIR                           
else                                                
        echo "Cleaning up app dir..."               
        rm -rf $APP_DIR/*                           
fi                                                  


#unzip the app in the apps dir
unzip $APP -d $APP_DIR        

#create environment variables passed to the build pack, these will be configured

#this is to simulate srvices bindings. TODO - paste here a json string with environment-specific bound services
export VCAP_SERVICES="{}"

#simulated application information
export VCAP_APPLICATION="{\"application_id\":\"b6e80a71-46e4-4854-b353-a8acb921b216\",\"application_name\":\"mulebuildpack\",\"application_uris\":[\"mulebuildpack.cfapps.io\"],\"application_version\":\"e8eee89d-2331-4d5e-ba9e-205582923d73\",\"host\":\"0.0.0.0\",\"instance_id\":\"b93c9dbd-6339-448d-5e72-09d40c19abbe\",\"instance_index\":0,\"limits\":{\"disk\":1024,\"fds\":16384,\"mem\":512},\"name\":\"jcwebapp\",\"port\":8080,\"space_id\":\"68882142-b4f7-44a1-9672-34fbceddd84a\",\"space_name\":\"development\",\"uris\":[\"mulebuildpack.cfapps.io\"],\"version\":\"e8eee89d-2331-4d5e-ba9e-205582923d73\"}"

export CF_INSTANCE_INDEX=0
export CF_INSTANCE_GUID=b93c9dbd-6339-448d-5e72-09d40c19abbe
export MEMORY_LIMIT=512m
export CF_INSTANCE_PORT=61508
export PORT=8080
export TMPDIR=$TEMP_DIR

#variables defined by the manifest
export ANYPOINT_ARM_HOST=anypoint.mulesoft.com
export ANYPOINT_ARM_ONPREM=
export ANYPOINT_USERNAME=
export ANYPOINT_PASSWORD=
export ANYPOINT_ENVIRONMENT=



#run the detect phase
$BP_DIR/bin/detect $APP_DIR $TEMP_DIR

if [ $? != 0 ]
then
       echo "ERROR: Build pack does not apply to app"
       exit 1
fi


#run the compile phase
$BP_DIR/bin/compile $APP_DIR $TEMP_DIR

if [ $? != 0 ]
then
       echo "ERROR: Compile phase failed."
       exit 1
fi

#finally run the release phase

$BP_DIR/bin/release $APP_DIR | ruby -e "require \"yaml\"; print YAML.load(STDIN.read)[\"default_process_types\"][\"web\"]"