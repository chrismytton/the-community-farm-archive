require 'bundler/setup'
require 'pry'
require 'scraperwiki'
require 'open-uri'
require 'digest'
require 'octokit'
require 'dotenv'

Dotenv.load
Octokit.access_token = ENV['MORPH_GITHUB_ACCESS_TOKEN']

class CommunityFarmPage
  attr_reader :res

  def initialize(res:)
    @res = res
  end

  def id
    @id ||= Digest::SHA1.hexdigest(html)
  end

  # Ignore the part of the html that changes on each page load.
  def html
    @html ||= res.read.gsub(%r{Memory Start: \d+</br>Memory End: \d+</br>Memory Peak: \d+</br>Time taken: \d+\.\d+</br>}, '[removed]')
  end

  def meta
    @meta ||= res.meta
  end

  def to_h
    {
      id: id,
      html: html,
      status: res.status.join(' '),
      created_at: DateTime.now.to_s,
    }
  end
end

class CommunityFarmArchive
  def initialize(url:)
    @url = url
  end

  def save
    save_response
    commit_html
  end

  private

  attr_reader :url

  def save_response
    ScraperWiki.save_sqlite([:id], page.to_h)

    page.meta.each do |header, value|
      ScraperWiki.save_sqlite(
        [:header, :value, :data_id],
        { header: header, value: value, data_id: page.id },
        'headers'
      )
    end
  end

  def commit_html(repo: 'communityfarm/api', filename: 'index.html')
    index_html = Octokit.contents(repo, path: filename)
    if Base64.decode64(index_html[:content]) == page.html
      warn "No changes to #{filename} detected"
    else
      Octokit.update_contents(
        repo,
        filename,
        "Update #{filename}",
        index_html[:sha],
        page.html,
        branch: 'master'
      )
    end
  rescue Octokit::NotFound => e
    warn "Couldn't find #{filename}: #{e.message}"
    Octokit.create_contents(
      repo,
      filename,
      "Create #{filename}",
      page.html,
      branch: 'master'
    )
  end

  def page
    @page ||= CommunityFarmPage.new(res: open(url))
  end
end

CommunityFarmArchive.new(url: 'https://www.thecommunityfarm.co.uk/boxes/box_display.php').save
