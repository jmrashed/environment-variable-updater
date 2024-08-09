# Environment Variable Updater

![GitHub](https://img.shields.io/github/license/jmrashed/environment-variable-updater)
![GitHub release (latest by date)](https://img.shields.io/github/v/release/jmrashed/environment-variable-updater)
![GitHub last commit](https://img.shields.io/github/last-commit/jmrashed/environment-variable-updater)
![GitHub issues](https://img.shields.io/github/issues/jmrashed/environment-variable-updater)
![GitHub pull requests](https://img.shields.io/github/issues-pr/jmrashed/environment-variable-updater)
![GitHub contributors](https://img.shields.io/github/contributors/jmrashed/environment-variable-updater)

![Environment Variable Updater](https://github.com/jmrashed/environment-variable-updater/blob/main/assets/directory.png)



## Introduction

The Environment Variable Updater is a shell script designed to streamline the process of updating environment variables in a `.env` file based on a given source file. This tool is particularly useful for managing environment-specific configurations in development and production setups.

## Contents

- [Environment Variable Updater](#environment-variable-updater)
  - [Introduction](#introduction)
  - [Contents](#contents)
  - [How It Works](#how-it-works)
  - [Why We Should Use This](#why-we-should-use-this)
  - [How to Install with Existing Project](#how-to-install-with-existing-project)
  - [Requirements](#requirements)
  - [Files Required](#files-required)
  - [How to Ensure Permissions](#how-to-ensure-permissions)
  - [How to Run with Parameters](#how-to-run-with-parameters)
  - [Contributions](#contributions)
  - [Author Info](#author-info)

## How It Works

1. **Folder Check:** The script verifies that it is executed from a directory containing the `environment-variable-updater` folder.
2. **Argument Validation:** It checks for the required argument (`local` or `server`) to determine which environment file to use.
3. **File Selection:** Based on the argument, the script selects the appropriate environment file (`.env.local` or `.env.server`).
4. **Backup and Create `.env`:** The script backs up the existing `.env` file if present, or creates a new one if it does not exist.
5. **Update or Append Variables:** The script reads the selected environment file, updates existing variables in the `.env` file, or appends new ones as needed.
6. **Replacement:** The original `.env` file is replaced with the updated content from a temporary file.

## Why We Should Use This

- **Consistency:** Ensures that environment variables are consistent and up-to-date across different environments.
- **Automation:** Automates the process of updating environment variables, reducing manual effort and potential errors.
- **Backup:** Automatically creates backups of the existing `.env` file to prevent data loss.

## How to Install with Existing Project

1. **Clone the Repository:**

   ```sh
   git clone git@github.com:jmrashed/environment-variable-updater.git
   ```

2. **Navigate to the Directory:**

   ```sh
   cd environment-variable-updater
   ```

3. **Ensure the Script is Executable:**

   ```sh
   chmod +x update-env.sh
   ```

## Requirements

- A Unix-like operating system (Linux, macOS)
- `bash` shell
- Basic Unix utilities (`grep`, `sed`, `cut`, `mv`)

## Files Required

- **`.env`:** The environment file to be updated.
- **`environment-variable-updater/.env.local`:** Environment variables for the local setup.
- **`environment-variable-updater/.env.server`:** Environment variables for the server setup.
- **`environment-variable-updater/update-env.sh`:** The script to update the `.env` file.

## How to Ensure Permissions

Ensure that the `update-env.sh` script is executable. You can set the appropriate permissions using:

```sh
chmod +x environment-variable-updater/update-env.sh
```

## How to Run with Parameters

To update the `.env` file using the `local` configuration:

```sh
./environment-variable-updater/update-env.sh local
```

To update the `.env` file using the `server` configuration:

```sh
./environment-variable-updater/update-env.sh server
```

## Contributions

Contributions are welcome! If you have suggestions, improvements, or bug fixes, please submit a pull request or open an issue in the repository.

## Author Info

- **Name:** Md Rasheduzzaman
- **Position:** Tech Lead at Onesttech LLC
- **Email:** [jmrashed@gmail.com](mailto:jmrashed@gmail.com)
- **Whatsapp:** +8801734446514
