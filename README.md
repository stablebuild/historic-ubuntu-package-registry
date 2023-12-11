# Set up an apt mirror with history

This is a companion repository to [StableBuild blog > Create a historic Ubuntu package mirror](https://stablebuild.com/blog/create-a-historic-ubuntu-package-mirror).

> Don't want to maintain a historic apt mirror yourself? [StableBuild](https://stablebuild.com) has you covered. We maintain hosted historic mirrors of the Ubuntu and Debian package registry, plus the most popular PPAs.

## Setup instructions

1. Provision a machine with plenty of storage. E.g. on AWS:

    * Type: `t2.medium`
    * 1x 30 GB SSD
    * 1x 6TB HDD

2. Log in to the server:

    ```
    ssh ubuntu@YOUR_IP
    ```

3. Install dependencies:

    ```
    sudo apt install -y zfsutils-linux apt-mirror nginx
    ```

4. Set up zfs filesystem on the HDD:

    ```
    # make a place to store all data
    sudo mkdir /debmirror

    # create zfs pool
    sudo zpool create -m /debmirror/live debmirror /dev/xvdb

    # make this owned by us
    cd /debmirror/live
    sudo chown -R ubuntu .
    ```

5. Clone this repository into /opt/debmirror.

    ```
    cd /opt
    sudo git clone git@github.com:stablebuild/historic-ubuntu-package-registry.git debmirror
    cd debmirror
    sudo chown -R ubuntu .
    ```

6. Symlink the mirror list and http config:

    ```
    # mirror list
    sudo rm -f /etc/apt/mirror.list
    sudo ln -s $PWD/mirror.list /etc/apt/mirror.list

    # nginx
    sudo rm /etc/nginx/sites-enabled/default
    sudo rm -f /etc/nginx/conf.d/debmirror.conf
    sudo ln -s $PWD/debmirror.conf /etc/nginx/conf.d/debmirror.conf
    sudo nginx -s reload
    ```

7. Run the mirror script in screen (because this will take a _long_ time the first run):

    ```
    screen

    sudo ./run-apt-mirror.sh
    ```

8. You should have a web server w/ a historic mirror available at http://YOUR_IP:8080

9. Set up a cron job to mirror daily:

    ```
    sudo crontab -e

    # Run daily
    40 10 * * * /opt/debmirror/run-apt-mirror.sh > /opt/debmirror/logs/`date +\%Y\%m\%d\%H\%M\%S`-cron.log 2>&1
    ```

10. Now to make this available to the internet:

    * EC2: Create a new target group, and include the server.
    * EC2: Create a new load balancer (_cannot be internal, otherwise CloudFront won't work_), and include the target group.
    * This should make the server available behind the ELB at f.e. http://internal-package-mirror-lb-8000000.eu-west-1.elb.amazonaws.com/
    * CloudFront: create a new distribution that maps to the load balancer.
        * For protocol make sure to pick _HTTP only_
        * Enable caching
        * Add the domain that you want to make this available under 'Alternate domain names' (e.g. debmirror.your-domain.com)
        * This should make the server available through CloudFront over both HTTP and HTTPS at f.e. https://dj23i7e3bd.cloudfront.net/
    * Route53: Register a new A record for the domain name (e.g. debmirror.your-domain.com)
        * Alias to: CloudFront distribution
        * Choose the CloudFront distribution created above
        * This should make the server available through both HTTP and HTTPS at f.e. https://debmirror.your-domain.com
    * Note that this does make the service available to the internet.

## Using the server

**x86**

```
$ docker run --rm -it --platform=linux/amd64 ubuntu:20.04 bash

# replace /etc/apt/sources.list with:
printf "\
deb http://debmirror.your-domain.com/2023-12-11T14:00:01Z/archive.ubuntu.com/ubuntu/ focal main restricted \n\
deb http://debmirror.your-domain.com/2023-12-11T14:00:01Z/archive.ubuntu.com/ubuntu/ focal-updates main restricted \n\
deb http://debmirror.your-domain.com/2023-12-11T14:00:01Z/archive.ubuntu.com/ubuntu/ focal universe \n\
deb http://debmirror.your-domain.com/2023-12-11T14:00:01Z/archive.ubuntu.com/ubuntu/ focal-updates universe \n\
deb http://debmirror.your-domain.com/2023-12-11T14:00:01Z/archive.ubuntu.com/ubuntu/ focal multiverse \n\
deb http://debmirror.your-domain.com/2023-12-11T14:00:01Z/archive.ubuntu.com/ubuntu/ focal-updates multiverse \n\
deb http://debmirror.your-domain.com/2023-12-11T14:00:01Z/archive.ubuntu.com/ubuntu/ focal-security main restricted \n\
deb http://debmirror.your-domain.com/2023-12-11T14:00:01Z/archive.ubuntu.com/ubuntu/ focal-security universe \n\
deb http://debmirror.your-domain.com/2023-12-11T14:00:01Z/archive.ubuntu.com/ubuntu/ focal-security multiverse \n\
" > /etc/apt/sources.list

$ apt update

# verify that we now get this from the mirror
$ apt install --print-uris -qq wget
```

**M1**

```
$ docker run --rm -it ubuntu:20.04 bash

# replace /etc/apt/sources.list with:
printf "\
deb http://debmirror.your-domain.com/2023-12-11T14:00:01Z/ports.ubuntu.com/ focal main restricted \n\
deb http://debmirror.your-domain.com/2023-12-11T14:00:01Z/ports.ubuntu.com/ focal-updates main restricted \n\
deb http://debmirror.your-domain.com/2023-12-11T14:00:01Z/ports.ubuntu.com/ focal universe \n\
deb http://debmirror.your-domain.com/2023-12-11T14:00:01Z/ports.ubuntu.com/ focal-updates universe \n\
deb http://debmirror.your-domain.com/2023-12-11T14:00:01Z/ports.ubuntu.com/ focal multiverse \n\
deb http://debmirror.your-domain.com/2023-12-11T14:00:01Z/ports.ubuntu.com/ focal-updates multiverse \n\
deb http://debmirror.your-domain.com/2023-12-11T14:00:01Z/ports.ubuntu.com/ focal-security main restricted \n\
deb http://debmirror.your-domain.com/2023-12-11T14:00:01Z/ports.ubuntu.com/ focal-security universe \n\
deb http://debmirror.your-domain.com/2023-12-11T14:00:01Z/ports.ubuntu.com/ focal-security multiverse \n\
" > /etc/apt/sources.list

$ apt update

# verify that we now get this from the mirror
$ apt install --print-uris -qq wget
```
