# -*- coding: utf-8 -*-
# あとで読む（仮）
require 'sqlite3'
require 'open-uri'

miquire :core, 'environment'
miquire :core, 'user'

Plugin.create(:save_url) do
  command(:save_include_url,
          name: '含まれているURLを保存',
          condition: Plugin::Command[:CanReplyAll],
          visible: true,
          role: :timeline) do |m|
    m.messages.map do |msg|
      save_include_url(msg)
    end
  end

  command(:save_tweet_url,
          name: 'ツイートのURLを保存',
          condition: Plugin::Command[:CanReplyAll],
          visible: true,
          role: :timeline) do |m|
    m.messages.map do |msg|
      save_tweet_url(msg)
    end
  end

  def get_html_title(url)
    title = url[0, 100] # defaultでURLの一部入れておけば大丈夫でしょ
    begin
      html = open(url).read
      if /<title>(.*)<\/title>/ =~ html
        title = $1
      end
    rescue => exception
      case exception
      when OpenURI::HTTPError
        # mikutterにページが見つからなかったことをpostさせる
      end
    end
    return title
  end

  def save_to_db(url, title)
    db = SQLite3::Database.new(File::expand_path(Environment::CONFROOT + "url_list.db"))
    tables = db.execute("SELECT tbl_name FROM sqlite_master WHERE type == 'table'").flatten
    
    unless tables.include?("url_list")
      sql = <<SQL
create table url_list (
  id integer primary key,
  title text,
  url text not null,
  delete_flg integer,
  date numeric
);
SQL
      db.execute(sql)
    end
    
    date = Time.new.strftime "%F %T" #%H:%M:%S %Y-%m-%dと一緒
    
    # DBへ格納
    sql = "insert into url_list values (null, :title, :url, 0, :date)"
    db.execute(sql, :title => title, :url => url, :date => date)

    db.close

    str = "@home " + title + " - " + url + " - " + date
    Post.primary_service.update(:message => str) # ここはシステムのツイート（？）にしたい
  end

  def save_include_url(message)
    urls = message[:message].scan(/http[s]?\:\/\/[\w\+\$\;\?\.\%\,\!\#\~\*\/\:\@\&\\\=\_\-]+/)
    if urls.length > 0
      # URLの展開したい
    else # なかった時の処理
      user = message[:user][:idname]
      msg_id = message[:id].to_s
      urls[0] = "http://twitter.com/#{user}/status/#{msg_id}"
    end
    urls.each do |url|
      title = get_html_title(url)
      save_to_db(url, title)
    end
  end

  def save_tweet_url(message)
    user = message[:user][:idname]
    msg_id = message[:id].to_s
    url = "http://twitter.com/#{user}/status/#{msg_id}"
    title = get_html_title(url)
    save_to_db(url, title)
  end
end
