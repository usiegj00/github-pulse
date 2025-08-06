# frozen_string_literal: true

require "octokit"
require "time"

module Github
  module Pulse
    class GithubClient
      attr_reader :client, :repo

      def initialize(repo:, token: nil)
        @repo = repo
        @client = if token
                    Octokit::Client.new(access_token: token)
                  else
                    Octokit::Client.new
                  end
        @client.auto_paginate = true
      end

      def pull_requests(since: nil, until_date: nil, state: "all")
        prs = client.pull_requests(repo, state: state)
        
        if since || until_date
          prs = filter_by_date(prs, since, until_date, &:created_at)
        end
        
        prs.map do |pr|
          {
            number: pr.number,
            title: pr.title,
            author: pr.user.login,
            created_at: pr.created_at,
            closed_at: pr.closed_at,
            merged_at: pr.merged_at,
            state: pr.state,
            additions: pr.additions || 0,
            deletions: pr.deletions || 0,
            changed_files: pr.changed_files || 0
          }
        end
      end

      def contributors_stats
        stats = client.contributors_stats(repo)
        return [] unless stats
        
        stats.map do |contributor|
          {
            author: contributor.author.login,
            total_commits: contributor.total,
            weeks: contributor.weeks.map do |week|
              {
                week_start: Time.at(week.w).to_date,
                additions: week.a,
                deletions: week.d,
                commits: week.c
              }
            end
          }
        end
      rescue Octokit::Accepted => e
        sleep 2
        retry
      end

      def commit_activity
        activity = client.commit_activity_stats(repo)
        return [] unless activity
        
        activity.map do |week|
          {
            week_start: Time.at(week.week).to_date,
            days: week.days,
            total: week.total
          }
        end
      rescue Octokit::Accepted => e
        sleep 2
        retry
      end

      def repository_info
        repo_data = client.repository(repo)
        {
          name: repo_data.name,
          full_name: repo_data.full_name,
          description: repo_data.description,
          created_at: repo_data.created_at,
          updated_at: repo_data.updated_at,
          language: repo_data.language,
          default_branch: repo_data.default_branch,
          size: repo_data.size,
          stars: repo_data.stargazers_count,
          forks: repo_data.forks_count,
          open_issues: repo_data.open_issues_count
        }
      end

      private

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
    end
  end
end