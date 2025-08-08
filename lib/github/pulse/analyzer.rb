# frozen_string_literal: true

require "time"
require_relative "date_helpers"

module Github
  module Pulse
    class Analyzer
      using DateHelpers
      attr_reader :repo_path, :github_repo, :token, :since, :until_date, :small_threshold, :medium_threshold

      def initialize(repo_path:, github_repo: nil, token: nil, since: nil, until: nil, small_threshold: 50, medium_threshold: 250)
        @repo_path = File.expand_path(repo_path)
        @github_repo = github_repo
        @token = token
        @since = since
        @until_date = binding.local_variable_get(:until)
        @small_threshold = small_threshold
        @medium_threshold = medium_threshold
      end

      def analyze
        report = {
          metadata: {
            analyzed_at: Time.now.iso8601,
            repository: nil,
            period: {
              since: since,
              until: until_date
            }
          },
          pull_requests: {},
          commits: {},
          lines_of_code: {},
          commit_activity: {},
          visualization_data: {}
        }

        # Try to analyze local git repository ONLY if no explicit GitHub repo is specified
        # OR if the local repo matches the specified GitHub repo
        should_analyze_local = false
        local_github_repo = nil
        
        if File.exist?(File.join(repo_path, ".git"))
          git_analyzer = GitAnalyzer.new(repo_path)
          local_github_repo = git_analyzer.remote_url
          
          # Only analyze local git if:
          # 1. No GitHub repo was specified (analyzing local only)
          # 2. The specified GitHub repo matches the local repo's remote
          if !github_repo || (github_repo == local_github_repo)
            should_analyze_local = true
            
            # Get commits by author
            commits = git_analyzer.analyze_commits(since: since, until_date: until_date)
            report[:commits] = format_commits_data(commits)
            
            # Get lines of code by author
            report[:lines_of_code] = git_analyzer.lines_of_code_by_author
            
            # Get commit activity
            report[:commit_activity] = git_analyzer.commit_activity_by_day
            
            # Set GitHub repo from remote if not specified
            @github_repo ||= local_github_repo
          end
        end

        # If we have GitHub repo info, fetch additional data
        if github_repo
          # Try gh CLI first if no token provided
          if !token
            require_relative "gh_client"
            gh_client = GhClient.new(repo: github_repo)
            
            if gh_client.available?
              puts "Using GitHub CLI (gh) for API access..."
              
              # Get repository info
              report[:metadata][:repository] = gh_client.repository_info
              
              # Get pull requests
              prs = gh_client.pull_requests(since: since, until_date: until_date)
              report[:pull_requests] = format_pull_requests_data(prs)
              
              # Get contributor statistics
              contrib_stats = gh_client.contributors_stats
              report[:contributor_stats] = format_contributor_stats(contrib_stats)
              
              # Get commits from GitHub if not analyzing local
              if !should_analyze_local
                commits = gh_client.commits_data(since: since, until_date: until_date)
                report[:commits] = format_commits_data(commits)
              end
              
              # Get commit activity from GitHub
              if report[:commit_activity].empty?
                activity = gh_client.commit_activity
                report[:commit_activity] = format_commit_activity(activity)
              end
            else
              puts "Warning: No GitHub token provided and gh CLI not available or not authenticated."
              puts "To enable GitHub features, either:"
              puts "  1. Set GITHUB_TOKEN environment variable"
              puts "  2. Install and authenticate gh CLI: https://cli.github.com"
            end
          else
            # Use token-based client
            github_client = GithubClient.new(repo: github_repo, token: token)
            
            # Get repository info
            report[:metadata][:repository] = github_client.repository_info
            
            # Get pull requests
            prs = github_client.pull_requests(since: since, until_date: until_date)
            report[:pull_requests] = format_pull_requests_data(prs)
            
            # Get contributor statistics
            contrib_stats = github_client.contributors_stats
            report[:contributor_stats] = format_contributor_stats(contrib_stats)
            
            # Get commits from GitHub if not analyzing local
            if !should_analyze_local
              # For token-based client, we'd need to implement a commits method
              # For now, contributor stats provides some commit data
            end
            
            # Get commit activity from GitHub
            if report[:commit_activity].empty?
              activity = github_client.commit_activity
              report[:commit_activity] = format_commit_activity(activity)
            end
          end
        end

        # Generate visualization data
        report[:visualization_data] = generate_visualization_data(report)

        report
      end

      private

      def format_commits_data(commits_by_author)
        formatted = {}
        
        commits_by_author.each do |author, commits|
          formatted[author] = {
            total_commits: commits.size,
            total_additions: commits.sum { |c| c[:additions] },
            total_deletions: commits.sum { |c| c[:deletions] },
            commits: commits.map do |c|
              {
                sha: c[:sha][0..7],
                message: c[:message],
                time: c[:time].iso8601,
                additions: c[:additions],
                deletions: c[:deletions]
              }
            end
          }
        end
        
        formatted
      end

      def format_pull_requests_data(prs)
        by_author = {}
        
        prs.each do |pr|
          author = pr[:author]
          by_author[author] ||= {
            total_prs: 0,
            merged: 0,
            open: 0,
            closed: 0,
            total_additions: 0,
            total_deletions: 0,
            pull_requests: []
          }
          
          by_author[author][:total_prs] += 1
          by_author[author][:merged] += 1 if pr[:merged_at]
          by_author[author][:open] += 1 if pr[:state] == "open"
          by_author[author][:closed] += 1 if pr[:state] == "closed" && !pr[:merged_at]
          by_author[author][:total_additions] += pr[:additions]
          by_author[author][:total_deletions] += pr[:deletions]
          
          by_author[author][:pull_requests] << {
            number: pr[:number],
            title: pr[:title],
            created_at: pr[:created_at].iso8601,
            merged_at: pr[:merged_at]&.iso8601,
            closed_at: pr[:closed_at]&.iso8601,
            state: pr[:state],
            merged: !pr[:merged_at].nil?,
            additions: pr[:additions],
            deletions: pr[:deletions],
            changed_files: pr[:changed_files]
          }
        end
        
        by_author
      end

      def format_contributor_stats(stats)
        return {} unless stats
        
        formatted = {}
        
        stats.each do |contributor|
          author = contributor[:author]
          formatted[author] = {
            total_commits: contributor[:total_commits],
            weekly_activity: contributor[:weeks].select { |w| w[:commits] > 0 }.map do |week|
              {
                week: week[:week_start].iso8601,
                commits: week[:commits],
                additions: week[:additions],
                deletions: week[:deletions]
              }
            end
          }
        end
        
        formatted
      end

      def format_commit_activity(activity)
        return {} unless activity
        
        activity_hash = {}
        
        activity.each do |week|
          date = week[:week_start]
          activity_hash[date.iso8601] = {
            total: week[:total],
            days: week[:days]
          }
        end
        
        activity_hash
      end

      def generate_visualization_data(report)
        viz_data = {}

        # Pull requests over time (for stacked bar chart)
        if report[:pull_requests].any?
          pr_timeline = Hash.new { |h, k| h[k] = Hash.new(0) }
          
          report[:pull_requests].each do |author, data|
            data[:pull_requests].each do |pr|
              date = Date.parse(pr[:created_at]).beginning_of_month.iso8601
              pr_timeline[date][author] += 1
            end
          end
          
          viz_data[:pull_requests_timeline] = pr_timeline.sort.map do |date, authors|
            { date: date, authors: authors }
          end
        end

        # Lines of code by author (for bar chart)
        if report[:lines_of_code].any?
          viz_data[:lines_of_code_chart] = report[:lines_of_code].map do |author, lines|
            { author: author, lines: lines }
          end.sort_by { |d| -d[:lines] }
        end

        # Commit activity over time (for line chart)
        if report[:commit_activity].any?
          viz_data[:commit_activity_chart] = report[:commit_activity].map do |date, count|
            { date: date.to_s, commits: count }
          end
        end

        # Commits by author over time (for stacked area chart)
        if report[:commits].any?
          commit_timeline = Hash.new { |h, k| h[k] = Hash.new(0) }
          
          report[:commits].each do |author, data|
            data[:commits].each do |commit|
              date = Date.parse(commit[:time]).beginning_of_week.iso8601
              commit_timeline[date][author] += 1
            end
          end
          
          viz_data[:commits_timeline] = commit_timeline.sort.map do |date, authors|
            { date: date, authors: authors }
          end
        end

        # Lines changed over time by author (additions + deletions)
        if report[:contributor_stats] && report[:contributor_stats].any?
          lines_timeline = Hash.new { |h, k| h[k] = Hash.new { |h2, k2| h2[k2] = { additions: 0, deletions: 0 } } }
          
          report[:contributor_stats].each do |author, data|
            data[:weekly_activity].each do |week|
              date = week[:week]
              lines_timeline[date][author][:additions] += week[:additions]
              lines_timeline[date][author][:deletions] += week[:deletions]
            end
          end
          
          viz_data[:lines_changed_timeline] = lines_timeline.sort.map do |date, authors|
            { date: date, authors: authors }
          end
        end

        # PR cycle time over time (p50/p90/max days by week)
        if report[:pull_requests].any?
          by_week = Hash.new { |h, k| h[k] = [] }
          report[:pull_requests].each do |_author, data|
            data[:pull_requests].each do |pr|
              next unless pr[:merged]
              begin
                created = Date.parse(pr[:created_at])
                # merged_at not stored in nested pr, but we track merged flag only; fall back to closed date when merged
                # We didn't include timestamps other than created_at; skip if unavailable
              rescue
                next
              end
            end
          end
          # We can compute cycle time only if detailed merged_at is available in PRs
          # The GitHub clients provide merged_at at top-level before formatting.
          # To preserve it, check if we stored it in pull_requests data; if not, skip this section.
          # Detect presence
          has_merged_at = report[:pull_requests].values.any? do |d|
            d[:pull_requests].any? { |pr| pr.key?(:merged_at) }
          end rescue false

          if has_merged_at
            by_week = Hash.new { |h, k| h[k] = [] }
            report[:pull_requests].each do |_author, data|
              data[:pull_requests].each do |pr|
                next unless pr[:merged]
                begin
                  created = Time.parse(pr[:created_at])
                  merged_at = Time.parse(pr[:merged_at])
                  days = ((merged_at - created) / 86400.0)
                  week = Date.parse(pr[:created_at]).beginning_of_week.iso8601
                  by_week[week] << days
                rescue
                  next
                end
              end
            end

            viz_data[:pr_cycle_time_timeline] = by_week.sort.map do |week, values|
              sorted = values.sort
              p50 = percentile(sorted, 0.5)
              p90 = percentile(sorted, 0.9)
              { week: week, p50: p50.round(2), p90: p90.round(2), max: sorted.last.round(2), count: values.size }
            end
          end
        end

        # PR size mix over time (small/medium/large by week)
        if report[:pull_requests].any?
          buckets_by_week = Hash.new { |h, k| h[k] = { small: 0, medium: 0, large: 0 } }
          report[:pull_requests].each do |_author, data|
            data[:pull_requests].each do |pr|
              begin
                additions = pr[:additions] || 0
                deletions = pr[:deletions] || 0
                size = additions + deletions
                week = Date.parse(pr[:created_at]).beginning_of_week.iso8601
                if size <= small_threshold
                  buckets_by_week[week][:small] += 1
                elsif size <= medium_threshold
                  buckets_by_week[week][:medium] += 1
                else
                  buckets_by_week[week][:large] += 1
                end
              rescue
                next
              end
            end
          end
          viz_data[:pr_size_mix_timeline] = buckets_by_week.sort.map { |week, counts| { week: week, **counts } }
        end

        # Commit activity heatmap (weekday x hour)
        if report[:commits].any?
          heatmap = Array.new(7) { Array.new(24, 0) }
          report[:commits].each do |_author, data|
            data[:commits].each do |commit|
              begin
                t = Time.parse(commit[:time])
                wday = t.wday # 0..6 (Sun..Sat)
                hour = t.hour
                heatmap[wday][hour] += 1
              rescue
                next
              end
            end
          end
          viz_data[:commit_activity_heatmap] = heatmap
        end

        # Open PRs aging buckets
        if report[:pull_requests].any?
          buckets = { "0-3d" => 0, "4-7d" => 0, "8-14d" => 0, "15+d" => 0 }
          report[:pull_requests].each do |_author, data|
            data[:pull_requests].each do |pr|
              next unless pr[:state] == "open"
              begin
                age_days = ((Time.now - Time.parse(pr[:created_at])) / 86400.0)
                key = case age_days
                      when 0..3 then "0-3d"
                      when 3...7 then "4-7d"
                      when 7...15 then "8-14d"
                      else "15+d"
                      end
                buckets[key] += 1
              rescue
                next
              end
            end
          end
          viz_data[:open_prs_aging] = buckets
        end

        viz_data
      end

      def percentile(sorted_values, p)
        return 0 if sorted_values.empty?
        rank = (p * (sorted_values.length - 1))
        lower = sorted_values[rank.floor]
        upper = sorted_values[rank.ceil]
        lower + (upper - lower) * (rank - rank.floor)
      end
    end
  end
end
