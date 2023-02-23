# BackupSystem

# Indice

- [Motivation](#Motivation)
- [Purpose](#Purpose)
- [Installation](#Installation)
- [Functionality](#Functionality)
- [Utilization](#Utilization)
- [Differences from other backup systems](#Differences-from-other-backup-systems)
- [Conclusion](#Conclusion)

## Motivation
The Backup Bash System was created to provide a reliable and easy-to-use backup solution in network environments. The idea stems from the need to make backups automatically and systematically, avoiding human errors and ensuring maximum data security.

## Purpose
The Backup Bash System solves the problem of having to manually backup large amounts of data, offering an automatic and customizable system to backup to multiple servers simultaneously. The system can also be used to create scheduled backups using cronjob.

## Installation
```bash
#clone repository
git clone https://github.com/MattiaCossu/BackupSystem.git

#add permissions
chmod +x backup.sh

#run script
bash backup.sh --help
```

## Functionality
The Backup Bash System comes with several features, including:
- Adding and removing target host
  ```bash
  #add (if the port is not defoult specified it will be the 22)
  bash backup.sh -a user@ip:port
  
  #remove
  bash backup.sh -a user:ip
  ```		
- Displaying the list of target host
  ```bash
  bash backup.sh -l
  ```		
- Manual backup of a single host
  ```bash
  bash backup.sh -m
  ```
- Backup of all host in the list
  ```bash
  bash backup.sh -A
  ```
- Setting and removing cronjob to create scheduled backup
  ```bash
  #set cronjob
  bash backup.sh -s

  #remove cronjob
  bash backup.sh -e

  #list all cronjob if are set
  bash backup.sh -L
  ```
## Utilization
To use the Backup Bash System simply run the bash backup.sh file and use the available options. You can use the -h or --help option to learn more about the available options and how to use them.

## Differences from other backup systems
The Backup Bash System differs from other backup systems for its ease of use and customizability. The system was created with the aim of simplifying the backup experience in the network environment, offering a customizable and flexible backup system, suitable for different needs.

## Conclusion
The Backup Bash System is a reliable and easy-to-use backup solution, ideal for creating backups in network environments. Thanks to its flexibility and customizability, the system is suitable for different needs, offering a simple and intuitive backup experience.



