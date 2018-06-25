require 'mechanize'
require 'nokogiri'
require 'twitter'
require 'time'
require 'pry'

SITE_URL = 'https://www.shogidojo.net/event/relay/23/c'

class Shogi24RelayBbsChecker
  def initialize(config_file)
    config = YAML.load_file(config_file)

    @login_name = config['shogi24']['name']
    @login_password = config['shogi24']['password']
    @boards = config['board']
    @data_file = config['data_file']
    @twitter_config = config['twitter']

    @agent = Mechanize.new
    @check_time = Time.now - 60 * 60 * 24 * 3  #３日前の投稿までを対象
  end

  def check_and_tweet
    raise "ログインに失敗しました。" unless bbs_login

    twitter_client do |client|
      get_new_arrival_posts.each do |post|
        tweet = '交流サイトに投稿がありました。（' + '投稿者：' + post[:name] + 'さん）' + "\n" + SITE_URL + '/team-bbs/bbs/' + post[:board_num].to_s
        client.update(tweet)
      end
    end
  end

  def twitter_client
    client = Twitter::REST::Client.new do |config|
      config.consumer_key = @twitter_config['consumer_key']
      config.consumer_secret = @twitter_config['consumer_secret']
      config.access_token = @twitter_config['access_token']
      config.access_token_secret = @twitter_config['access_token_secret']
    end
    yield(client)
  end

  def bbs_login
    @agent.get(SITE_URL + '/users/login') do |page|
      response = page.form_with(:action => URI.parse(SITE_URL + '/users/login').path) do |form|
        form.field_with(:name => 'name').value = @login_name
        form.field_with(:name => 'pass').value = @login_password
      end.submit

      if (msg = response.at('div.message'))
        msg.inner_text.match(/ログインしました/) do |md|
          return true
        end
      end
    end
    false
  end

  def get_new_arrival_posts
    new_arrival_posts = []
    data = {}
    if File.exist?(@data_file)
      data = YAML.load_file(@data_file)
    end

    get_posts.each do |post|
      key = [post[:board_num].to_s, post[:time].to_s, post[:name]].join('-')
      unless data.has_key?(key)
        new_arrival_posts << post
        data[key] = post
      end
    end
    YAML.dump(data, File.open(@data_file, 'w'))

    new_arrival_posts
  end

  def get_posts
    posts = []

    @boards.each do |board_num|
      @agent.get(SITE_URL + '/team-bbs/bbs/' + board_num.to_s) do |page|
        page.search('div.teamBbs table tr').each do |tr|
          td = tr.search('td')
          next if td.empty?

          post_time = Time.parse(td[0].inner_text)
          if post_time > @check_time
            posts << {
              :board_num => board_num,
              :time => post_time,
              :name => td[1].inner_text,
              :body => td[2].inner_text,
            }
          end
        end
      end
    end
    posts
  end
end

checker = Shogi24RelayBbsChecker.new('config.yaml')
checker.check_and_tweet
