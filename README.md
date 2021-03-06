# lxc-lamp

**lxc-lamp.sh** - is an easy script to install container for Linux. Includes the Nginx web server, MySQL, PHP, and adminer.

I am a web developer, I have been using this container for several years and find it convenient.

Five components (frequently used for web development in php world):

- ubuntu 20.04 
- php 7.4
- mariadb 10.3.25 (mysql)
- nginx 1.18.0
- adminer 4.8.0 

All this packed in one light container for your future webapp.

You press one button and everything unfolds at its best, take it and enjoy it.\
I wholeheartedly hope you get a similar experience. :o)


**Tested on:** Ubuntu 18.04, Ubuntu 20.04

One script and only 200 lines of code with comments!\
Feel free to edit and adapt it for your project.


### Getting started

1. Insltall ``lxc``: ``$ sudo apt install lxc``
2. Figure out what your application will be called. For this example: **myapp**
3. Then open terminal:
 ```bash
 $ git clone https://github.com/agorlov/lxc-lamp.git myapp
 $ cd myapp
 $ sudo bash ./lxc-lamp.sh myapp
 
 (here myapp is name of lxc container)
 ..wait for few minutes..
 ```
3. Open your template app in browser: http://10.0.3.31/ (where 10.03.31 is your internal container addess)
4. Start editing ``index.php`` 
5. Put some static files to **myapp/public** dir (``myapp/public -> /www/public``)


#### Useful facts and commands

- Your project working directory mapped to inside container:\
  example: ``/home/alexandr/myapp -> /www``\
  So, work with your files directly in the app folder.
- List lxc containers and its ``ip-addresses``: ``sudo lxc-ls -f``
- Start container: ``sudo lxc-start myapp``
- Go to the container: ``sudo lxc-attach myapp``
- Stop container: ``sudo lxc-stop myapp``
- Remove container: ``sudo lxc-destroy myapp``
- All container files stored in ``/var/lib/lxc/myapp/rootfs`` as regular files!
  To delete a container, you can actually delete a directory ``/var/lib/lxc/myapp/``
- Static files and document root in **myapp/public** ex.: ``myapp/public/example.css``
- Starting point of your app is **myapp/index.php**
- DB access: http://10.0.3.112/adminer (user and password: myapp)
- Lxc-container configuration file: ``/var/lib/lxc/myapp/config``

### Getting started on existing project

In this example, your project in directory: **myProject**

```
$ cd myProject
$ wget https://raw.githubusercontent.com/agorlov/lxc-lamp/main/lxc-lamp.sh
$ sudo bash ./lxc-lamp.sh myProject
```
### Known issues

Message like:
```
Starting myapp...
lxc-start: myapp1: lxccontainer.c: wait_on_daemonized_start: 851 Received container state "ABORTING" instead of "RUNNING"
...
```
workaround is to edit: ``/etc/lxc/default.conf`` and add string: ``lxc.apparmor.profile = unconfined``, 
then start again ``sudo bash ./lxc-lamp.sh myapp``

More info on issue: https://github.com/lxc/lxc/issues/1895




## Why lxc?

- It's architecture is most suitable for multi-component services.
  Historically, this is what php web applications are.
- No need to learn much, learn three facts and you are already working ``\o/``

**Docker** is good for one process - one container.
**LXC** is good for multiple system components - one service.


