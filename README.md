# What is Taiga?

Taiga is a project management platform for startups and agile developers & designers who want a simple, beautiful tool that makes work truly enjoyable.

> [taiga.io](https://taiga.io)

# How to use this image

This is a fork from [benhutchins/docker-taiga](https://github.com/benhutchins/docker-taiga) so the credit for the good work is for him. I've just made some changes to this in order to get it running in OpenShift cloud.

## Deploy Taiga in OpenShift
First of all, you need to download this project and the submodule inside pointing the official Taiga repository.<br/>
```bash
git clone https://github.com/jialvarez/taiga_openshift.git && cd taiga_openshift/
git submodule update --init --remote
git checkout openshift
```
Then, you can deploy it in two different ways:

### Deploying directly into OpenShift project

1. Just login into your cluster:<br/>
```oc login https://api.<starter_or_pro>-<location>.openshift.com --token=<token>```

2. Select a project:<br/>
```oc project <project_name>```

3. Start the conversion and deployment proccess <br/>
```kompose --file docker-compose.yml --provider openshift --verbose up```<br/><br/>
Image generation can take a big time, so please be patient.
<br/><br/>
If you want to remove pods, deployments, and volumes generated, you should type:<br/>
```kompose --file docker-compose.yml --provider openshift --verbose down```

### Generating templates and then deploy into OpenShift project

1. Just login into your cluster:<br/>
```oc login https://api.<starter_or_pro>-<location>.openshift.com --token=<token>```

2. Select a project:<br/>
```oc project <project_name>```

3. Generate templates<br/>
```mkdir templates && kompose --provider openshift -v convert -f docker-compose.yml -o templates/```

4. Apply them<br/>
```kubectl apply -f templates/```

## Deploy Odoo in Docker containers
You should change to the docker-compose branch:
```git checkout docker-compose```
or
```git checkout docker-compose-events```

if you want to give a try to Taiga Events.

And then just type:<br/>
```docker-compose up -d```
