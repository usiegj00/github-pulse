# frozen_string_literal: true

require "json"
require "time"
require "open3"

module Github
  module Pulse
    class GhClient
      attr_reader :repo

      def initialize(repo:)
        @repo = repo
        validate_gh_cli!
      end

      def available?
        @gh_available
      end

      def pull_requests(since: nil, until_date: nil, state: "all")
        limit = 1000
        fields = "number,title,author,createdAt,closedAt,mergedAt,state,additions,deletions,changedFiles"
        
        cmd = ["gh", "pr", "list", "--repo", repo, "--limit", limit.to_s, "--json", fields]
        
        # gh doesn't support filtering by date directly, so we get all and filter
        case state
        when "open"
          cmd += ["--state", "open"]
        when "closed"
          cmd += ["--state", "closed"]
        when "merged"
          cmd += ["--state", "merged"]
        else
          # For "all", we need to make multiple calls
          open_prs = execute_gh_command(cmd + ["--state", "open"])
          closed_prs = execute_gh_command(cmd + ["--state", "closed"])
          merged_prs = execute_gh_command(cmd + ["--state", "merged"])
          prs = open_prs + closed_prs + merged_prs
        end
        
        prs ||= execute_gh_command(cmd)
        
        # Filter by date if needed
        if since || until_date
          prs = filter_by_date(prs, since, until_date) { |pr| Time.parse(pr["createdAt"]) }
        end
        
        prs.map do |pr|
          {
            number: pr["number"],
            title: pr["title"],
            author: pr.dig("author", "login") || "unknown",
            created_at: parse_time(pr["createdAt"]),
            closed_at: parse_time(pr["closedAt"]),
            merged_at: parse_time(pr["mergedAt"]),
            state: pr["state"].downcase,
            additions: pr["additions"] || 0,
            deletions: pr["deletions"] || 0,
            changed_files: pr["changedFiles"] || 0
          }
        end
      end

      def repository_info
        fields = "name,nameWithOwner,description,createdAt,updatedAt,primaryLanguage,defaultBranchRef,diskUsage,stargazerCount,forkCount,issues"
        cmd = ["gh", "repo", "view", repo, "--json", fields]
        
        data = execute_gh_command(cmd)
        return nil unless data && !data.empty?
        data = data.is_a?(Array) ? data.first : data
        
        {
          name: data["name"],
          full_name: data["nameWithOwner"],
          description: data["description"],
          created_at: parse_time(data["createdAt"]),
          updated_at: parse_time(data["updatedAt"]),
          language: data.dig("primaryLanguage", "name"),
          default_branch: data.dig("defaultBranchRef", "name"),
          size: data["diskUsage"],
          stars: data["stargazerCount"],
          forks: data["forkCount"],
          open_issues: data.dig("issues", "totalCount") || 0
        }
      end

      def commit_activity
        # gh doesn't have a direct equivalent to commit activity stats
        # We can get recent commits and group them by week
        days_back = 52 * 7 # Get a year of data
        since_date = (Date.today - days_back).to_s
        
        url = "repos/#{repo}/commits?since=#{since_date}"
        cmd = ["gh", "api", url]
        
        commits = execute_gh_command(cmd)
        return [] unless commits.is_a?(Array)
        
        # Group by week
        activity = Hash.new(0)
        commits.each do |commit|
          date_str = commit.dig("commit", "author", "date")
          next unless date_str
          
          date = Date.parse(date_str)
          week_start = date - date.cwday + 1
          activity[week_start] += 1
        end
        
        activity.map do |week_start, count|
          days = [0] * 7
          # We don't have daily granularity from this API, so distribute evenly
          days[0] = count
          
          {
            week_start: week_start,
            days: days,
            total: count
          }
        end
      end
      
      def commits_data(since: nil, until_date: nil)
        # Fetch commit data from GitHub
        # Build query string for parameters
        params = []
        params << "since=#{since}" if since
        params << "until=#{until_date}" if until_date
        
        url = "repos/#{repo}/commits"
        url += "?#{params.join('&')}" unless params.empty?
        
        cmd = ["gh", "api", url]
        
        commits = execute_gh_command(cmd)
        
        # Group commits by author
        commits_by_author = Hash.new { |h, k| h[k] = [] }
        
        commits.each do |commit|
          author = commit.dig("author", "login") || commit.dig("commit", "author", "email") || "unknown"
          
          commits_by_author[author] << {
            sha: commit["sha"],
            message: commit.dig("commit", "message")&.lines&.first&.strip,
            time: parse_time(commit.dig("commit", "author", "date")),
            additions: 0,  # GitHub API doesn't provide this in commits list
            deletions: 0   # Would need individual commit API calls
          }
        end
        
        commits_by_author
      end

      def contributors_stats
        # Use gh api to get contributor statistics
        cmd = ["gh", "api", "repos/#{repo}/stats/contributors", "--cache", "1h"]
        
        stats = execute_gh_command(cmd)
        return [] unless stats && stats.is_a?(Array)
        
        stats.map do |contributor|
          {
            author: contributor.dig("author", "login") || "unknown",
            total_commits: contributor["total"],
            weeks: (contributor["weeks"] || []).map do |week|
              {
                week_start: Time.at(week["w"]).to_date,
                additions: week["a"],
                deletions: week["d"],
                commits: week["c"]
              }
            end
          }
        end
      end

      private

      def validate_gh_cli!
        # Check if gh is installed
        _, _, status = Open3.capture3("which", "gh")
        unless status.success?
          @gh_available = false
          return
        end
        
        # Check if gh is authenticated
        _, stderr, status = Open3.capture3("gh", "auth", "status")
        if status.success? || stderr.include?("Logged in")
          @gh_available = true
        else
          @gh_available = false
        end
      rescue StandardError
        @gh_available = false
      end

      def execute_gh_command(cmd)
        stdout, stderr, status = Open3.capture3(*cmd)
        
        # For paginated requests, gh may return partial success
        # Check if we got any data even if status indicates an error
        if !stdout.strip.empty?
          begin
            # Try to parse the output we did get
            result = JSON.parse(stdout)
            return result
          rescue JSON::ParserError
            # Some gh api commands return newline-delimited JSON
            return stdout.lines.map { |line| JSON.parse(line.strip) rescue nil }.compact
          end
        end
        
        unless status.success?
          if stderr.include?("HTTP 404") || stderr.include?("not found")
            return []
          end
          raise Error, "gh command failed: #{stderr}"
        end
        
        []
      end

      def filter_by_date(items, since, until_date)
        items.select do |item|
          date = yield(item)
          next false unless date
          
          date_check = true
          date_check &&= date >= Time.parse(since) if since
          date_check &&= date <= Time.parse(until_date) if until_date
          date_check
        end
      end

      def parse_time(time_str)
        return nil unless time_str
        Time.parse(time_str)
      rescue StandardError
        nil
      end
    end
  end
end