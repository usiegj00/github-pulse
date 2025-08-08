# GitHub Pulse

GitHub Pulse is a Ruby gem that analyzes GitHub repository activity to provide insights into team contributions, including pull requests, lines of code, and commit activity. It generates visualization-ready JSON output perfect for creating charts and dashboards.

## Features

- **Pull Request Analysis**: Track PRs by teammate over time
- **Lines of Code Analysis**: See current code ownership by contributor
- **Commit Activity**: Monitor commit patterns and frequency
- **PR Cycle Time**: Weekly p50/p90/max merge times
- **PR Size Mix**: Small/medium/large PR composition over time
- **Open PR Aging**: Buckets of aging open PRs
- **Commit Heatmap**: Activity by weekday and hour
- **Local Git Support**: Analyze repositories directly from local git data
- **GitHub API Integration**: Enhanced data when GitHub token is provided
- **Visualization-Ready Output**: JSON formatted for easy chart generation

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'github-pulse'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install github-pulse

## Usage

### Basic Usage

Analyze the current directory (must be a git repository):

```bash
github-pulse analyze
```

### With GitHub API Access

For enhanced data including pull requests and detailed statistics, you have three options:

#### Option 1: Use GitHub CLI (Recommended)
If you have the GitHub CLI installed and authenticated, the gem will automatically use it:

```bash
# Install and authenticate gh CLI (one-time setup)
brew install gh  # or your package manager
gh auth login

# Then just run the analyzer
github-pulse analyze
```

#### Option 2: Use Environment Variable
```bash
export GITHUB_TOKEN=your_github_token
github-pulse analyze
```

#### Option 3: Pass Token Directly
```bash
github-pulse analyze --token=your_github_token
```

### Analyze a Specific Repository

```bash
# Local repository
github-pulse analyze /path/to/repo

# With GitHub repository specified
github-pulse analyze --repo=owner/repository --token=your_token
```

### Date Filtering

Analyze activity within a specific time period:

```bash
github-pulse analyze --since=2024-01-01 --until=2024-12-31
```

### Output Options

```bash
# Pretty-printed JSON (default: compact JSON)
github-pulse analyze --format=pretty

# Custom output file (default: github-pulse-report.json)
github-pulse analyze --output=my-report.json

# Interactive HTML report
github-pulse analyze --format=html

# Tune PR size buckets (total additions+deletions)
github-pulse analyze --format=html --small_threshold 50 --medium_threshold 250
```

## Output Format

The gem generates a comprehensive JSON report with the following structure:

```json
{
  "metadata": {
    "analyzed_at": "2024-01-15T10:30:00Z",
    "repository": { /* repository details */ },
    "period": { "since": "2024-01-01", "until": "2024-12-31" }
  },
  "pull_requests": {
    "username": {
      "total_prs": 15,
      "merged": 12,
      "open": 2,
      "closed": 1,
      "total_additions": 500,
      "total_deletions": 200,
      "pull_requests": [ /* detailed PR list */ ]
    }
  },
  "commits": {
    "email@example.com": {
      "total_commits": 50,
      "total_additions": 1000,
      "total_deletions": 300,
      "commits": [ /* detailed commit list */ ]
    }
  },
  "lines_of_code": {
    "email@example.com": 5000
  },
  "commit_activity": {
    "2024-01-01": 5,
    "2024-01-02": 3
  },
  "visualization_data": {
    "pull_requests_timeline": [ /* ready for stacked bar chart */ ],
    "lines_of_code_chart": [ /* ready for bar chart */ ],
    "commit_activity_chart": [ /* ready for line chart */ ],
    "commits_timeline": [ /* ready for stacked area chart */ ],
    "lines_changed_timeline": [ /* weekly additions/deletions by author */ ],
    "pr_cycle_time_timeline": [ /* weekly p50/p90/max days */ ],
    "pr_size_mix_timeline": [ /* weekly small/medium/large PR counts */ ],
    "open_prs_aging": { /* aging buckets for open PRs */ },
    "commit_activity_heatmap": [[ /* 7x24 grid of commit counts */ ]]
  }
}
```

## Visualization Data

The `visualization_data` section contains pre-formatted data ready for charting libraries:

- **pull_requests_timeline**: Data for stacked bar charts showing PRs by author over time
- **lines_of_code_chart**: Bar chart data showing current code ownership
- **commit_activity_chart**: Line chart data for overall repository activity
- **commits_timeline**: Stacked area chart data for commits by author over time
- **lines_changed_timeline**: Weekly additions/deletions by author (GitHub stats)
- **pr_cycle_time_timeline**: Weekly median/percentile merge times (days)
- **pr_size_mix_timeline**: Weekly mix of small/medium/large PRs
- **open_prs_aging**: Counts of open PRs bucketed by age
- **commit_activity_heatmap**: 7 rows (Sun–Sat) x 24 columns (hours)

## Requirements

- Ruby 3.1 or higher
- Git (for local repository analysis)
- GitHub personal access token (optional, for enhanced features)

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`.

Note: Some PR metrics (size, timestamps) are richer when authenticated via GitHub CLI (`gh auth login`) or with `GITHUB_TOKEN`. Octokit list endpoints may omit additions/deletions; the HTML report will gracefully degrade when fields are unavailable.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/usiegj00/github-pulse.
