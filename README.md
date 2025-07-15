-----

# GitHub Profile Screener

A set of scripts (Ruby and Python) that analyze a GitHub user's public profile and gather statistics about their repositories. It evaluates lines of code and documentation, the distribution of programming languages, and commit activity.

-----

## Features

  * **Code Analysis:** Counts the total lines of code across all public repositories.
  * **Documentation Analysis:** Counts the lines of all `README` files.
  * **Language Statistics:** Creates a percentage breakdown of all programming languages used.
  * **Activity Overview:** Sums up commits from the last year as an indicator of user activity.

-----

## Setup and Configuration

Follow these steps to get the scripts running.

### 1\. Install Dependencies

Depending on which script you want to use, you will need to install the corresponding dependencies.

#### For Ruby

This script requires the `octokit` gem to interact with the GitHub API. Install it via your terminal:

```bash
gem install octokit
```

#### For Python

This script requires the `PyGithub` and `PyYAML` libraries. Install them via your terminal:

```bash
pip install PyGithub PyYAML
```

### 2\. Create a GitHub Personal Access Token

A **GitHub Personal Access Token** is required for API requests.

1.  Go to your GitHub Settings → **Developer settings**.
2.  Navigate to **Personal access tokens** → **Tokens (classic)**.
3.  Click on **Generate new token**.
4.  Give the token a name (e.g., "Git-Screener-Script").
5.  Select the **`public_repo`** scope. This is sufficient for read-only access to public repositories.
6.  Copy the generated token. **⚠️ Important:** This token is only displayed once\! Treat it like a password.

-----

## Usage

The scripts **no longer need to be edited**. Configuration is handled interactively.

### Running an Analysis

To start an analysis, simply run one of the two scripts in your terminal:

**Python Version:**

```bash
python3 github_screener.py
```

**Ruby Version:**

```bash
ruby 2025_Github_Screener.rb
```

On the first run, you will be prompted to enter your GitHub username and your previously created token. This information is saved to a `config.yml` file for all future runs.

-----

## Performance Comparison (Benchmark)

The project includes a shell script (`benchmark.sh`) to directly compare the speed of the Python and Ruby versions.

1.  **Make the script executable:**
    ```bash
    chmod +x benchmark.sh
    ```
2.  **Run the benchmark:**
    ```bash
    ./benchmark.sh
    ```

The script will run both analysis tools, measure the time, and show which version was faster.

-----

## Important Notes

  * **API Rate Limits:** The script sends many requests to the GitHub API. For users with a large number of repositories, the API rate limit (approx. 5,000 requests/hour) might be reached.
  * **Performance:** The analysis can take some time, depending on the number of repositories and files.
  * **Security:** The `config.yml` file contains your private access token. **Never commit this file to a public repository\!** It is strongly recommended to add it to your `.gitignore` file:
    ```
    # .gitignore
    config.yml
    ```
