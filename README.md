-----

# GitHub Profile Screener

A simple Ruby script that analyzes a GitHub user's public profile and gathers statistics about their repositories. It evaluates the number of code and documentation lines, the distribution of programming languages, and commit activity.

-----

## Features

  * **Code Analysis:** Counts the total lines of code across all public repositories.
  * **Documentation Analysis:** Counts the lines of all `README` files.
  * **Language Statistics:** Creates a percentage breakdown of all programming languages used.
  * **Activity Overview:** Sums up the commits from the last year as an indicator of user activity.

-----

## Setup & Configuration

Follow these steps to get the script running.

### 1\. Install Required Gems

This script requires the `octokit` gem to interact with the GitHub API. Install it via your terminal:

```bash
gem install octokit
```

### 2\. Create a GitHub Personal Access Token

A **GitHub Personal Access Token** is required for API requests.

1.  Go to your GitHub Settings → **Developer settings**.
2.  Navigate to **Personal access tokens** → **Tokens (classic)**.
3.  Click on **Generate new token**.
4.  Give it a name (e.g., "Git-Screener-Script").
5.  Select the **`public_repo`** scope. This is sufficient for read-only access to public repositories.
6.  Copy the generated token. **⚠️ Important:** This token is only displayed once\! Treat it like a password.

-----

## Usage

1.  Open the script file (`2025_Github_Screener.rb`) in an editor.

2.  Enter the required attributes directly into the code:

      * **`ACCESS_TOKEN`**: Replace the placeholder with your previously created GitHub token.
      * **`GITHUB_USER`**: Enter the GitHub username you want to analyze.

    <!-- end list -->

    ```ruby
    # ...
    # CONFIGURATION
    # ===================================================================

    # Add your token here
    ACCESS_TOKEN = ENV['GITHUB_TOKEN'] || 'ghp_YourRealTokenHere12345'

    # The GitHub username to be analyzed.
    GITHUB_USER = 'UsernameHere'

    # ===================================================================
    # ...
    ```

3.  Run the script in your terminal:

    ```bash
    ruby 2025_Github_Screener.rb
    ```

The script will now start the analysis and print the results to the terminal.

-----

## Important Notes

  * **API Rate Limits:** The script sends many requests to the GitHub API. For users with a large number of repositories, the API rate limit (approx. 5,000 requests/hour) might be reached.
  * **Performance:** The analysis can take some time, depending on the number of repositories and files.
  * **Security:** **Never** hardcode your token in a public repository. For secure usage, you should load the token from an environment variable (`ENV['GITHUB_TOKEN']`).
