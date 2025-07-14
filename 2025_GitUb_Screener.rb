# git_screener.rb

require 'octokit'
require 'base64'

# ===================================================================
# KONFIGURATION
# ===================================================================

# WICHTIG: Ersetze 'DEIN_GITHUB_TOKEN' mit deinem Personal Access Token.
# Behandle diesen Token wie ein Passwort und teile ihn nicht.
# Am besten ist es, ihn über eine Umgebungsvariable zu laden.
ACCESS_TOKEN = ENV['GITHUB_TOKEN'] || 'YOUR_TOKEN'

# Der GitHub-Benutzername, der analysiert werden soll.
GITHUB_USER = 'NAME_HERE'

# ===================================================================

# Überprüfen, ob ein Token gesetzt ist
if ACCESS_TOKEN == 'YOUR_TOKEN'
  puts "Fehler: Bitte setze deinen GitHub Personal Access Token in der Zeile `ACCESS_TOKEN`."
  exit
end

puts "Initialisiere Screener für den Nutzer: #{GITHUB_USER}..."

# Client mit dem Token authentifizieren
client = Octokit::Client.new(access_token: ACCESS_TOKEN)

# Sicherstellen, dass der Nutzer existiert
begin
  user = client.user(GITHUB_USER)
rescue Octokit::NotFound
  puts "Fehler: Der Nutzer '#{GITHUB_USER}' wurde nicht gefunden."
  exit
end

# Initialisierung der Zähler
total_lines_of_code = 0
total_lines_of_docs = 0
total_commits = 0
language_stats = Hash.new(0)

# Alle öffentlichen Repositories des Nutzers abfragen
puts "Frage alle öffentlichen Repositories ab..."
begin
  repos = client.repos(GITHUB_USER)
rescue Octokit::Error => e
  puts "Fehler bei der API-Abfrage: #{e.message}"
  exit
end

puts "Analyse von #{repos.size} Repositories gestartet. Das kann eine Weile dauern..."
puts "---"

# Jedes Repository durchgehen
repos.each_with_index do |repo, index|
  full_repo_name = repo.full_name
  puts "[#{index + 1}/#{repos.size}] Analysiere: #{full_repo_name}"

  # 1. Sprachstatistiken abrufen und aggregieren
  begin
    repo_langs = client.languages(full_repo_name)
    repo_langs.to_h.each do |lang, bytes|
      language_stats[lang] += bytes
    end

    # 2. README für Dokumentationszeilen zählen
    begin
      readme = client.readme(full_repo_name)
      # Inhalt ist Base64-kodiert
      readme_content = Base64.decode64(readme.content)
      total_lines_of_docs += readme_content.lines.count
    rescue Octokit::NotFound
      # Kein README gefunden, nichts tun.
    end

    # 3. Alle Code-Zeilen zählen (API-intensiv!)
    # Holt den letzten Commit des Default-Branches
    last_commit_sha = client.branch(full_repo_name, repo.default_branch).commit.sha
    # Holt die Dateistruktur (rekursiv)
    tree = client.tree(full_repo_name, last_commit_sha, recursive: true).tree

    tree.each do |file|
      # Nur Dateien (blobs) und keine zu großen Dateien analysieren, um Timeout zu vermeiden
      next unless file.type == 'blob' && file.size > 0 && file.size < 1_000_000 # Limit: 1MB

      begin
        blob = client.blob(full_repo_name, file.sha)
        # Nur Textdateien berücksichtigen
        if blob.encoding == 'base64'
            content = Base64.decode64(blob.content)
            # Prüfen, ob der Inhalt gültiges UTF-8 ist, um Binärdateien zu überspringen
            if content.valid_encoding?
                total_lines_of_code += content.lines.count
            end
        end
      rescue Octokit::NotFound, Octokit::ServerError
        # Blob konnte nicht geholt werden, überspringen.
      end
    end

    # 4. Aussagen über Aktivität (Anzahl der Commits)
    # Hinweis: Dies zählt nur die letzten Commits (bis zu 100 pro Seite).
    # Eine vollständige Zählung erfordert das Durchgehen aller Seiten (Pagination).
    # Für eine einfache Metrik nehmen wir die Commits des letzten Jahres.
    repo_commits = client.commit_activity_stats(full_repo_name)
    total_commits += repo_commits.map(&:total).sum if repo_commits
  rescue Octokit::Error => e
    puts "Konnte das Repository '#{full_repo_name}' nicht vollständig analysieren: #{e.message}"
  end
end

puts "\n---"
puts "✅ Analyse abgeschlossen!"
puts "---"

# Ergebnisse aufbereiten und ausgeben
puts "\n📊 Ergebnisse für #{user.name} (@#{GITHUB_USER})"
puts "=============================================="
puts "Gesamte Code-Zeilen: #{total_lines_of_code.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1.').reverse}"
puts "Gesamte Doku-Zeilen (in READMEs): #{total_lines_of_docs.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1.').reverse}"
puts "Gesamte Commits (letztes Jahr): #{total_commits.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1.').reverse}"
puts "\n💻 Verwendete Programmiersprachen:"

total_bytes = language_stats.values.sum
if total_bytes > 0
  # Nach Größe sortieren und nur relevante Sprachen anzeigen
  sorted_langs = language_stats.sort_by { |_lang, bytes| -bytes }

  sorted_langs.each do |lang, bytes|
    percentage = (bytes.to_f / total_bytes * 100).round(2)
    puts "  - #{lang}: #{percentage}%" if percentage > 0.1
  end
else
    puts "Keine Sprachdaten gefunden."
end

puts "=============================================="