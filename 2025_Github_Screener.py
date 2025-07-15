import os
import sys
import base64
import re
from collections import Counter

import yaml
from github import Github, GithubException

# ===================================================================
# CONFIGURATION
# ===================================================================

CONFIG_FILE = 'config.yml'

def load_or_create_config():
    """Lädt die Konfiguration oder startet die interaktive Einrichtung."""
    config = {}
    if os.path.exists(CONFIG_FILE):
        with open(CONFIG_FILE, 'r') as f:
            config = yaml.safe_load(f) or {}

    if not config.get('GITHUB_USER') or config.get('GITHUB_USER') == 'USER_NAME' or not config.get('ACCESS_TOKEN') or config.get('ACCESS_TOKEN') == 'YOUR_TOKEN':
        print("Konfiguration nicht gefunden oder unvollständig. Bitte jetzt einrichten.")
        
        config['GITHUB_USER'] = input("Gib deinen GitHub-Benutzernamen ein: ")
        config['ACCESS_TOKEN'] = input("Gib dein GitHub Personal Access Token ein: ")

        with open(CONFIG_FILE, 'w') as f:
            yaml.dump(config, f)
        print(f"✅ Konfiguration wurde in '{CONFIG_FILE}' gespeichert.\n")
    
    return config

# Stop-Wörter, um relevantere Ergebnisse zu erhalten.
STOP_WORDS = {
    'https', 'http', 'href', 'com', 'github', 'bash', 'www', 'org', 'de', 'a', 'about', 'an', 'and', 'are', 
    'as', 'at', 'be', 'by', 'for', 'from', 'how', 'i', 'in', 'is', 'it', 'of', 'on', 'or', 'that', 'the', 
    'this', 'to', 'was', 'what', 'when', 'where', 'who', 'will', 'with', 'he', 'she', 'they', 'we', 'me', 
    'you', 'my', 'your', 'our', 'do', 'not', 'have', 'were', 'if', 'then', 'else', 'while', 'code', 'file', 
    'files', 'gem', 'build', 'setup', 'config', 'run', 'installation', 'usage', 'license', 'mit', 'gpl', 
    'data', 'lib', 'docs', 'new', 'get', 'use', 'using', 'via', 'from', 'these', 'those', 'example', 
    'examples', 'please', 'feel', 'free', 'more', 'also', 'just', 'like', 'some', 'any', 'all', 'its', 
    'can', 'readme', 'md', 'out', 'there', 'because', 'been', 'through', 'into', 'only', 'repo', 
    'repository', 'project', 'projects', 'app', 'application', 'service', 'api', 'client', 'server', 
    'test', 'tests', 'feature', 'features', 'version', 'update', 'release', 'change', 'fix', 'add', 
    'remove', 'refactor', 'style', 'chore', 'ci', 'performance', 'security', 'support', 'help', 
    'contact', 'information', 'details', 'note', 'important'
}

# ===================================================================

def process_and_count_words(text, counter):
    """Extrahiert und zählt Wörter aus einem Text."""
    if not text:
        return
    words = re.findall(r'[a-z0-9]+', text.lower())
    for word in words:
        if word not in STOP_WORDS and len(word) >= 3:
            counter[word] += 1

def main():
    """Hauptfunktion des Skripts."""
    config = load_or_create_config()
    
    ACCESS_TOKEN = os.environ.get('GITHUB_TOKEN') or config['ACCESS_TOKEN']
    GITHUB_USER = config['GITHUB_USER']

    print(f"Initializing screener for user: {GITHUB_USER}...")

    # Authentifiziere den Client
    g = Github(ACCESS_TOKEN)

    # Stelle sicher, dass der Benutzer existiert
    try:
        user = g.get_user(GITHUB_USER)
    except GithubException as e:
        if e.status == 404:
            print(f"Error: User '{GITHUB_USER}' not found.")
        elif e.status == 401:
            print("Error: GitHub Token ist ungültig oder hat nicht die nötigen Rechte.")
        else:
            print(f"An unexpected error occurred: {e}")
        sys.exit()

    # Initialisiere Zähler und Sammlungen
    total_lines_of_code = 0
    total_lines_of_docs = 0
    total_commits = 0
    language_stats = Counter()
    repo_names = []
    first_activity_date = None
    last_activity_date = None
    keyword_counts = Counter()

    # Hole alle öffentlichen Repositories
    print("Fetching all public repositories...")
    repos = list(user.get_repos())
    repo_count = len(repos)
    print(f"Starting analysis of {repo_count} repositories. This may take a while...")
    print("---")

    # Iteriere durch jedes Repository
    for i, repo in enumerate(repos):
        print(f"[{i + 1}/{repo_count}] Analyzing: {repo.full_name}")
        
        # 1. Sammle Repo-Namen
        repo_names.append(repo.full_name)

        # 2. Verfolge erstes und letztes Aktivitätsdatum
        if first_activity_date is None or repo.created_at < first_activity_date:
            first_activity_date = repo.created_at
        if last_activity_date is None or repo.pushed_at < last_activity_date:
            last_activity_date = repo.pushed_at
        
        # 3. Verarbeite Schlüsselwörter aus dem Repo-Namen
        process_and_count_words(re.sub(r'[-_]', ' ', repo.name), keyword_counts)

        try:
            # 4. Analysiere den Inhalt des Repos
            # Sprachstatistiken
            for lang, byte_count in repo.get_languages().items():
                language_stats[lang] += byte_count

            # README-Analyse
            try:
                readme = repo.get_readme()
                readme_content = base64.b64decode(readme.content).decode('utf-8', errors='ignore')
                total_lines_of_docs += len(readme_content.splitlines())
                process_and_count_words(readme_content, keyword_counts)
            except GithubException:
                pass # Kein README gefunden

            # Zeilen Code zählen
            tree = repo.get_git_tree(repo.default_branch, recursive=True).tree
            for element in tree:
                if element.type == 'blob' and 0 < element.size < 1_000_000:
                    try:
                        blob_content = repo.get_git_blob(element.sha).content
                        decoded_content = base64.b64decode(blob_content).decode('utf-8', errors='ignore')
                        total_lines_of_code += len(decoded_content.splitlines())
                    except Exception:
                        pass # Konnte Blob nicht verarbeiten

            # Commit-Aktivität (letztes Jahr)
            commit_stats = repo.get_stats_commit_activity()
            if commit_stats:
                total_commits += sum(stat.total for stat in commit_stats)

        except GithubException as e:
            print(f"Could not fully analyze repository '{repo.full_name}': {e.data.get('message', 'API Error')}")

    print("\n---")
    print("✅ Analysis complete!")
    print("---")

    # Ergebnisse formatieren und ausgeben
    print(f"\n📊 Results for {user.name} (@{GITHUB_USER})")
    print("==============================================")

    print("\n🗓️ Activity Span")
    print(f"First activity (oldest repo): {first_activity_date.strftime('%Y-%m-%d') if first_activity_date else 'N/A'}")
    print(f"Last activity (latest push):  {last_activity_date.strftime('%Y-%m-%d') if last_activity_date else 'N/A'}")

    print("\n📈 General Statistics")
    print(f"Total lines of code: {total_lines_of_code:,}")
    print(f"Total documentation lines (in READMEs): {total_lines_of_docs:,}")
    print(f"Total commits (last year): {total_commits:,}")

    print("\n🔑 Top 10 Keywords (from Repo Names & READMEs)")
    if not keyword_counts:
        print("No keywords found.")
    else:
        for i, (word, count) in enumerate(keyword_counts.most_common(10)):
            print(f"{i + 1}. {word} ({count} mentions)")

    print("\n💻 Programming Languages Used:")
    total_bytes = sum(language_stats.values())
    if total_bytes > 0:
        sorted_langs = sorted(language_stats.items(), key=lambda item: item[1], reverse=True)
        for lang, byte_count in sorted_langs:
            percentage = (byte_count / total_bytes * 100)
            if percentage > 0.1:
                print(f"   - {lang}: {percentage:.2f}%")
    else:
        print("No language data found.")

    print(f"\n📚 Repository List ({len(repo_names)} total)")
    for name in repo_names:
        print(f"   - {name}")

    print("==============================================")


if __name__ == '__main__':
    main()