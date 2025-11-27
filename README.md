# Remote Docker Lab

This repository contains two scripts that help you create and remove isolated Docker-based project environments on a remote machine.

The goal is to let you run heavy code (CPU-intensive, RAM-intensive, GPU-dependent, or long-running experiments) **on a remote server**, without installing or running anything locally besides SSH.

---

# Files

### 1. create_project.sh  
Creates a complete folder for a new project on a remote server and prepares it for Docker usage.

### 2. remove_project.sh  
Deletes a project folder and its associated Docker environment from the remote server.

Both scripts run **entirely from your local machine** via SSH.

---

# Requirements

**Local machine**
- Bash
- SSH client

**Remote machine**
- SSH access
- Docker installed
- Permission to create and delete directories

---

# How to Use

Below are the **exact command-line instructions**.

---

# 1. Create a New Remote Project

### Syntax

```bash
./create_project.sh <remote_user>@<remote_host> <project_name>
