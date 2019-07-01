#! /usr/bin/env ruby
require 'erb'
require 'logger'
require 'mechanize'
require 'nokogiri'
require 'twitter'
require 'time'
require 'dotenv'
Dotenv.load(__dir__ + '/.env')

class ShogiClub24RelayBbsChecker
  def initialize(config_file)
    @check_time = Time.now - 60 * 60 * 24 * 3  #３日前の投稿までを対象

    @config = YAML::load(ERB.new(IO.read(config_file)).result)
    @board_base_url = @config['board']['base_url']
    @board_ids = @config['board']['ids']

    @agent = Mechanize.new
    @logger = Logger.new(STDOUT)
    @cache_data = {}
  end

  def check_and_tweet
    raise "ログインに失敗しました。" unless bbs_login

    load_cache

    twitter_client do |client|
      get_new_arrival_posts.each do |post|
        tweet = '交流サイトに投稿がありました。'
        tweet += '（投稿者：' + post[:name] + 'さん）'
        tweet += post[:body][0..3] + '... '
        tweet += @board_base_url + '/team-bbs/bbs/' + post[:board_id].to_s
        @logger.info('New tweet: ' + tweet)
        begin
          client.update(tweet)
        rescue => e
          @logger.info('Failed: ' + e.to_s)
          key = [post[:board_id].to_s, post[:time].to_s, post[:name]].join('-')
          @cache_data.delete(key)
        end
        sleep(5)
      end
    end

    save_cache
  end

  def twitter_client
    client = Twitter::REST::Client.new do |config|
      config.consumer_key = @config['twitter']['consumer_key']
      config.consumer_secret = @config['twitter']['consumer_secret']
      config.access_token = @config['twitter']['access_token']
      config.access_token_secret = @config['twitter']['access_token_secret']
    end
    yield(client)
  end

  def bbs_login
    @agent.get(@board_base_url + '/users/login') do |page|
      response = page.form_with(:action => URI.parse(@board_base_url + '/users/login').path) do |form|
        form.field_with(:name => 'name').value = @config['account']['username']
        form.field_with(:name => 'pass').value = @config['account']['password']
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

    read_posts.each do |post|
      key = [post[:board_id].to_s, post[:time].to_s, post[:name]].join('-')
      unless @cache_data.has_key?(key)
        new_arrival_posts << post
        @cache_data[key] = post
      end
    end

    new_arrival_posts
  end

  def read_posts
    posts = []

    @board_ids.each do |id|
      @agent.get(@board_base_url + '/team-bbs/bbs/' + id.to_s) do |page|
        page.search('div.teamBbs table tr').each do |tr|
          td = tr.search('td')
          next if td.empty?

          post_time = Time.parse(td[0].inner_text)
          if post_time > @check_time
            posts << {
              :board_id => id,
              :time => post_time,
              :name => td[1].inner_text,
              :body => td[2].inner_text,
            }
          end
        end
      end
    end

    posts.reverse!
    posts
  end

  def load_cache
    if File.exist?(@config['cache_data_file'])
      data = YAML.load_file(@config['cache_data_file'])
      @cache_data = data if data.kind_of?(Hash)
    end
  end

  def save_cache
    YAML.dump(@cache_data, File.open(@config['cache_data_file'], 'w'))
  end
end

checker = ShogiClub24RelayBbsChecker.new(__dir__ + '/config.yaml')
checker.check_and_tweet
