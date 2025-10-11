# Moodle container image for Production with Persistent Plugins & Themes

This repository provides a specialized Docker image for deploying a scalable, production-ready Moodle instance where **all components, including custom plugins and themes, persist** across upgrades and scaling events.

## The Problem with Standard container deployments

In a typical containerized setup, the Moodle application code is baked into the container image. This creates a major challenge:

  * **Plugins & Themes are Lost:** When you install a new plugin or theme, it's written to the filesystem of a running container. If you scale up, the new containers won't have it. If you deploy an updated image for a new Moodle version, all the plugins and themes you installed on the previous version are gone.
  * **Complex Upgrades:** Upgrading Moodle requires building a new image, manually re-integrating all your plugins and themes, and deploying it, which can be complex and lead to downtime.

This project is designed to solve this problem permanently.

## The Solution: Decoupling Code from Containers

The solution is to treat the Moodle application code itself—not just the `moodledata` directory—as persistent state. This is achieved by storing the entire Moodle codebase (`/var/www/html`) on a shared, elastic network file system like **Amazon EFS**.

This Docker image is not just another Moodle image. It's a lightweight PHP runtime armed with the tools (`git`) to manage a Moodle installation that lives on this external shared storage.

### How It Works

1.  **Persistent Storage:** You mount an EFS volume to `/var/www` The `/var/www/html` (moodle application) and `/var/www/moodledata` (moodle data) for all your containers.
2.  **Initial Install:** On first launch, the container detects the `/var/www/html` directory is empty and `git clone`s the official Moodle repository onto your EFS volume.
3.  **Full Persistence:** You can now install plugins and themes. They are saved directly to the EFS volume, outside of any container.
4.  **Flawless Scaling:** When you launch new containers, they mount the same EFS volume and instantly have the exact same Moodle core code, plugins, and themes as all the other containers.
5.  **Effortless Upgrades:** To upgrade Moodle, you simply `exec` into a running container and use `git pull` to update the core code. Your plugins and themes are in separate directories and are untouched by the process, remaining perfectly intact.

This architecture, inspired by modern cloud practices like the [AWS Moodle modernization guide](https://aws.amazon.com/blogs/publicsector/modernize-moodle-lms-aws-serverless-containers/), ensures your Moodle environment is truly scalable, resilient, and easy to maintain.

## Key Advantages

  * **Never Lose a Plugin Again:** Your entire application state—plugins, themes, and data—survives container restarts, deployments, and scaling events.
  * **True Horizontal Scaling:** Autoscale your container fleet with confidence, knowing every new instance will be a perfect, state-aware clone.
  * **Simple, In-Place Upgrades:** Update Moodle core with a simple `git pull` command without ever needing to rebuild or redeploy your Docker image.
  * **Decoupled & Modern:** The container is a disposable runtime; your valuable Moodle application lives securely on persistent storage.

## Deployment Guide

### Prerequisites

  * A container orchestrator (AWS ECS, Kubernetes, etc.).
  * A shared file system (e.g., Amazon EFS) for application code and data.
  * A managed database (e.g., Amazon RDS).
  * A managed cache (e.g., Amazon ElastiCache for Redis).


## How to create a new image

- Inside a repository directory where Dockerfile exist, run below command:

```
docker build -t moodle:<TAG> .

```

## Usage Options

This image download and setup an moodle environment based on enironment variables that you supply in the docker command line or through docker-compose/swarm. Before you can use this container, you need to install and setup an database. After that, you'll need to provide the following information (through ENVIRONMENT variables):

 * MOODLE_DB_HOST: Address of Database Host;
 * MOODLE_DB_PORT: Port of Database;
 * MOODLE_DB_USER: Name of Database User;
 * MOODLE_DB_PASSWORD: Password of Database User;
 * MOODLE_DB_PREFIX: Name of Database Prefix;
 * MOODLE_DB_TYPE: Type of Database;
 * MOODLE_DB_NAME: Database Name;
 * MOODLE_REDIS_HOST: Address of Redis Host;
 * MOODLE_REDIS_PORT: Port of Database;
 * MOODLE_URL: wwwroot of moodle, must match with the server access fqdn;
 * MOODLE_SERVER_NAME: FQDN of the server;
 * MOODLE_ADMIN_USER: Name of Moodle User;
 * MOODLE_ADMIN_PASS: Password of Moodle User;

## Upgrade moodle

### Enable Maintenance
```
    docker exec -it <server_container> bash -c "sudo -u apache /usr/bin/php /var/www/html/moodle/admin/cli/maintenance.php --enable"
 ```   
### Pull from moodle
```
    docker exec -it <server_container> bash -c "cd /var/www/html/moodle && git branch --track MOODLE_<VERSION>_STABLE origin/MOODLE_<VERSION>_STABLE && git checkout MOODLE_<VERSION>_STABLE -f && git pull" 
```
### Upgrade moodle
 ```
    docker exec -it <server_container> bash -c "sudo -u apache /usr/bin/php /var/www/html/moodle/admin/cli/upgrade.php "
```
### Disable Maintenance
```
    docker exec -it <server_container> bash -c "sudo -u apache /usr/bin/php /var/www/html/moodle/admin/cli/maintenance.php --disable"
```

## Contributions

Are extremely welcome!