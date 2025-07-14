# git_screener.rb

require 'octokit'
require 'base64'

# ===================================================================
# CONFIGURATION
# ===================================================================

# IMPORTANT: Replace 'YOUR_TOKEN' with your Personal Access Token.
# Treat this token like a password and do not share it.
# It's best practice to load it from an environment variable.
ACCESS_TOKEN = ENV['GITHUB_TOKEN'] || 'YOUR_TOKEN'

# The GitHub username to be analyzed.
GITHUB_USER = 'USER_NAME'

# ===================================================================

# Check if a token has been set
if ACCESS_TOKEN == 'YOUR_TOKEN'
  puts "Error: Please set your GitHub Personal Access Token in the `ACCESS_TOKEN` line."
  exit
end

puts "Initializing screener for user: #{GITHUB_USER}..."

# Authenticate the client with the token
client = Octokit::Client.new(access_token: ACCESS_TOKEN)

# Make sure the user exists
begin
  user = client.user(GITHUB_USER)
rescue Octokit::NotFound
  puts "Error: User '#{GITHUB_USER}' not found."
  exit
end

# Initialize counters
total_lines_of_code = 0
total_lines_of_docs = 0
total_commits = 0
language_stats = Hash.new(0)

# Fetch all public repositories for the user
puts "Fetching all public repositories..."
begin
  repos = client.repos(GITHUB_USER)
rescue Octokit::Error => e
  puts "Error during API request: #{e.message}"
  exit
end

puts "Starting analysis of #{repos.size} repositories. This may take a while..."
puts "---"

# Iterate through each repository
repos.each_with_index do |repo, index|
  full_repo_name = repo.full_name
  puts "[#{index + 1}/#{repos.size}] Analyzing: #{full_repo_name}"

  # 1. Fetch and aggregate language statistics
  begin
    repo_langs = client.languages(full_repo_name)
    repo_langs.to_h.each do |lang, bytes|
      language_stats[lang] += bytes
    end

    # 2. Count README lines for documentation stats
    begin
      readme = client.readme(full_repo_name)
      # Content is Base64-encoded
      readme_content = Base64.decode64(readme.content)
      total_lines_of_docs += readme_content.lines.count
    rescue Octokit::NotFound
      # No README found, do nothing.
    end

    # 3. Count all lines of code (API-intensive!)
    # Get the last commit of the default branch
    last_commit_sha = client.branch(full_repo_name, repo.default_branch).commit.sha
    # Get the file tree (recursively)
    tree = client.tree(full_repo_name, last_commit_sha, recursive: true).tree

    tree.each do |file|
      # Only analyze files (blobs) and avoid files that are too large to prevent timeouts
      next unless file.type == 'blob' && file.size > 0 && file.size < 1_000_000 # Limit: 1MB

      begin
        blob = client.blob(full_repo_name, file.sha)
        # Only consider text files
        if blob.encoding == 'base64'
            content = Base64.decode64(blob.content)
            # Check if the content is valid UTF-8 to skip binary files
            if content.valid_encoding?
                total_lines_of_code += content.lines.count
            end
        end
      rescue Octokit::NotFound, Octokit::ServerError
        # Blob could not be fetched, skipping.
      end
    end

    # 4. Information about activity (number of commits)
    # Note: This only counts commits from the last year.
    # A full count would require iterating through all pages (pagination).
    repo_commits = client.commit_activity_stats(full_repo_name)
    total_commits += repo_commits.map(&:total).sum if repo_commits
  rescue Octokit::Error => e
    puts "Could not fully analyze repository '#{full_repo_name}': #{e.message}"
  end
end

puts "\n---"
puts "✅ Analysis complete!"
puts "---"

# Format and print the results
puts "\n📊 Results for #{user.name} (@#{GITHUB_USER})"
puts "=============================================="
puts "Total lines of code: #{total_lines_of_code.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
puts "Total documentation lines (in READMEs): #{total_lines_of_docs.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
puts "Total commits (last year): #{total_commits.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
puts "\n💻 Programming Languages Used:"

total_bytes = language_stats.values.sum
if total_bytes > 0
  # Sort by size and only show relevant languages
  sorted_langs = language_stats.sort_by { |_lang, bytes| -bytes }

  sorted_langs.each do |lang, bytes|
    percentage = (bytes.to_f / total_bytes * 100).round(2)
    puts "  - #{lang}: #{percentage}%" if percentage > 0.1
  end
else
    puts "No language data found."
end

puts "=============================================="