# frozen_string_literal: true

require 'octokit'
require 'base64'
require 'set'
require 'yaml' # Hinzugefügt für die Konfigurationsdatei

# ===================================================================
# CONFIGURATION MANAGEMENT
# ===================================================================

CONFIG_FILE = 'config.yml'

# Lädt die Konfiguration aus der YAML-Datei.
# Wenn die Datei nicht existiert oder unvollständig ist, wird eine interaktive Einrichtung gestartet.
def load_or_create_config
  config = if File.exist?(CONFIG_FILE)
             YAML.load_file(CONFIG_FILE) || {}
           else
             {}
           end

  if config['GITHUB_USER'].nil? || config['GITHUB_USER'] == 'USER_NAME' || config['ACCESS_TOKEN'].nil? || config['ACCESS_TOKEN'] == 'YOUR_TOKEN'
    puts "Konfiguration nicht gefunden oder unvollständig. Bitte jetzt einrichten."
    
    print "Gib deinen GitHub-Benutzernamen ein: "
    config['GITHUB_USER'] = gets.chomp
    
    print "Gib dein GitHub Personal Access Token ein: "
    config['ACCESS_TOKEN'] = gets.chomp

    File.write(CONFIG_FILE, config.to_yaml)
    puts "✅ Konfiguration wurde in '#{CONFIG_FILE}' gespeichert.\n"
  end
  
  config
end

# Lade die Konfiguration
config = load_or_create_config

# Weise die Konfigurationswerte den Konstanten zu.
# Das Umgebungstoken hat weiterhin Vorrang.
ACCESS_TOKEN = ENV['GITHUB_TOKEN'] || config['ACCESS_TOKEN']
GITHUB_USER = config['GITHUB_USER']

# Stop-Wörter bleiben unverändert
STOP_WORDS = Set.new(%w(
  https http href com github bash www org de a about an and are as at be by for from how i in is it of on or that the this to was what when where who will with the to and of a in is it for on that as with he she they we me you my your our I be have do not have was were if then else for while do code file files gem build setup config run installation usage license mit gpl data lib docs new get use using via from this that these those an example examples please feel free to more also just like some any all its can not will readme md out there because been through into only repo repository project projects app application service api client server test tests feature features version update release change fix add remove refactor style docs chore ci build performance security support help contact information details note important))

# ===================================================================
# SCRIPT LOGIC (unverändert)
# ===================================================================

puts "Initializing screener for user: #{GITHUB_USER}..."

# Authenticate the client with the token
client = Octokit::Client.new(access_token: ACCESS_TOKEN)

# Make sure the user exists
begin
  user = client.user(GITHUB_USER)
rescue Octokit::NotFound
  puts "Error: User '#{GITHUB_USER}' not found."
  exit
rescue Octokit::Unauthorized
  puts "Error: GitHub Token ist ungültig oder hat nicht die nötigen Rechte."
  exit
end

# Initialize counters and collectors
total_lines_of_code = 0
total_lines_of_docs = 0
total_commits = 0
language_stats = Hash.new(0)
repo_names = []
first_activity_date = nil
last_activity_date = nil
keyword_counts = Hash.new(0)

# Helper function for keyword analysis
def process_and_count_words(text, counts)
  return unless text && !text.empty?
  words = text.downcase.scan(/[a-z0-9]+/) # Extract words/numbers
  words.each do |word|
    next if STOP_WORDS.include?(word) || word.length < 3
    counts[word] += 1
  end
end

# Fetch all public repositories for the user
puts "Fetching all public repositories..."
repos = client.repos(GITHUB_USER)

puts "Starting analysis of #{repos.size} repositories. This may take a while..."
puts "---"

# Iterate through each repository
repos.each_with_index do |repo, index|
  full_repo_name = repo.full_name
  puts "[#{index + 1}/#{repos.size}] Analyzing: #{full_repo_name}"
  
  # 1. Collect repo name
  repo_names << full_repo_name

  # 2. Track first and last activity dates
  if first_activity_date.nil? || repo.created_at < first_activity_date
    first_activity_date = repo.created_at
  end
  if last_activity_date.nil? || repo.pushed_at > last_activity_date
    last_activity_date = repo.pushed_at
  end
  
  # 3. Process keywords from repo name
  process_and_count_words(repo.name.gsub(/[-_]/, ' '), keyword_counts)
  
  # 4. Analyze repo contents
  begin
    # Language statistics
    repo_langs = client.languages(full_repo_name)
    repo_langs.to_h.each { |lang, bytes| language_stats[lang] += bytes }

    # README analysis (docs lines and keywords)
    begin
      readme = client.readme(full_repo_name)
      readme_content = Base64.decode64(readme.content)
      total_lines_of_docs += readme_content.lines.count
      process_and_count_words(readme_content, keyword_counts)
    rescue Octokit::NotFound
      # No README found
    end

    # Lines of code count
    last_commit_sha = client.branch(full_repo_name, repo.default_branch).commit.sha
    tree = client.tree(full_repo_name, last_commit_sha, recursive: true).tree
    tree.each do |file|
      next unless file.type == 'blob' && file.size > 0 && file.size < 1_000_000 # Limit: 1MB
      begin
        blob = client.blob(full_repo_name, file.sha)
        if blob.encoding == 'base64' && (content = Base64.decode64(blob.content)).valid_encoding?
          total_lines_of_code += content.lines.count
        end
      rescue Octokit::Error
        # Blob could not be fetched
      end
    end

    # Commit activity
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

# Activity Dates
puts "\n🗓️ Activity Span"
puts "First activity (oldest repo): #{first_activity_date&.strftime('%Y-%m-%d') || 'N/A'}"
puts "Last activity (latest push):  #{last_activity_date&.strftime('%Y-%m-%d') || 'N/A'}"

# General Stats
puts "\n📈 General Statistics"
puts "Total lines of code: #{total_lines_of_code.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
puts "Total documentation lines (in READMEs): #{total_lines_of_docs.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
puts "Total commits (last year): #{total_commits.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"

# Top 10 Keywords
puts "\n🔑 Top 10 Keywords (from Repo Names & READMEs)"
if keyword_counts.empty?
  puts "No keywords found."
else
  top_10_keywords = keyword_counts.sort_by { |_, count| -count }.first(10)
  top_10_keywords.each_with_index do |(word, count), i|
    puts "#{i + 1}. #{word} (#{count} mentions)"
  end
end

# Programming Languages
puts "\n💻 Programming Languages Used:"
total_bytes = language_stats.values.sum
if total_bytes > 0
  sorted_langs = language_stats.sort_by { |_, bytes| -bytes }
  sorted_langs.each do |lang, bytes|
    percentage = (bytes.to_f / total_bytes * 100).round(2)
    puts "   - #{lang}: #{percentage}%" if percentage > 0.1
  end
else
  puts "No language data found."
end

# Repository List
puts "\n📚 Repository List (#{repo_names.size} total)"
repo_names.each { |name| puts "   - #{name}" }

puts "=============================================="