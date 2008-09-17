require "rubygems"
require "rdiscount"
BlueCloth ||= RDiscount
require "haml"
require "sass"
require "sinatra"
require "md5"

$secret  = '47dcbc6ee81ad88ed5e0bf3caa18ae07'
$secret2 = '51a00c3fa95770ad305f2e869d02636b'

enable :sessions

#done: security
#TODO: deploy
#done: RSS
#done: save edit names
#done: history list
#done: rollback
#TODO: history diffs
#TODO: error catching

get '/' do
  $text = RDiscount.new( File.read("text.markdown") ).to_html
  $css  = Sass::Engine.new( File.read("style.sass") ).render
  $html = Haml::Engine.new( File.read("template.haml") ).to_html
  File.open("index.html","w"){|f| f.puts($html)}
  next $html
end

get '/rss' do
  $uid = `git-rev-list HEAD ^HEAD~1`
  $text = RDiscount.new( File.read("text.markdown") ).to_html
  header 'Content-Type' => 'application/atom+xml'
  haml <<-HAML
!!! XML
%feed{:xmlns=>"http://www.w3.org/2005/Atom"}
  %title FEED
  %entry
    %title update
    %link{:rel=>"alternate", :type=>"text/html", :href=>"/"}
    %id= $uid
    %content{:type=>'html'}= html_escape $text
  HAML
end


get '/pancake' do
  haml <<-HAML
%html
  %body
    %form{:method=>'POST'}
      %label{:for=>'name'} name
      %input#name{:name=>'name', :value=>request.cookies['name']}
      %label{:for=>'password'} Password
      %input#password{:type=>'password',:name=>'password'}
      %input{:type=>'submit', :value=>'go', :default=>'1'}
    %a{:href=>'/'} back
  HAML
end

post '/pancake' do
  password = params['password']
  if MD5.hexdigest(password) == $secret
    set_cookie('name', params['name'])
    set_cookie('password',  MD5.hexdigest($secret + password))
  end
  redirect '/head'
end

get '/onion' do
  set_cookie('password', nil)
  redirect '/pancake'
end

get '/head' do
  editor("text.markdown", "[markdown](http://daringfireball.net/projects/markdown/syntax)")
end

get '/sugar' do
  editor("style.sass", "[sass](http://haml.hamptoncatlin.com/docs/rdoc/classes/Sass.html)")
end

get '/ham' do
  editor("template.haml", "[haml](http://haml.hamptoncatlin.com/docs/rdoc/classes/Haml.html)")
end

post '/sugar' do
  save("style.sass")
  redirect '/sugar'
end
post '/ham' do
  save("template.haml")
  redirect '/ham'
end
post '/head' do
  save("text.markdown")
  redirect '/head'
end

helpers do
  def navigation
    RDiscount.new( <<-MARKDOWN ).to_html
[VIEW](/)
EDIT:
[content](/head)
[style](/sugar)
[layout](/ham)
[LOGOUT](/onion)
    MARKDOWN
  end

  def editor(file, text = nil)
    authorize

    log = `git log #{file}`
    data = []
    log.split("\n").each do |line|
      if( line =~ /^commit\s*(.*)/ )
        data.push({:commit => $1})
        next
      end
      if( line =~ /^Date:\s*(.*)/ )
        data.last.update({:date=> $1})
        next
      end
      if( line =~ /^Author:\s*(.*)/ )
        data.last.update({:author=> $1})
        next
      end
      data.last[:text] ||= ''
      data.last[:text] += line.strip + "\n" unless line.strip.empty?
    end

    history = ""
    data.each do | dat |
      description = "#{dat[:date]} #{dat[:text]}"
      history += <<-HAML
      %a{:href=>"?commit=#{dat[:commit]}"}= #{ description.inspect }
      %br/
      HAML
    end

    blob = nil 
    if params[:commit]
      ls = `git-ls-tree #{params[:commit].inspect}`
      ls.split("\n").each do | line |
        if(line.index file)
          line =~ /[0-9]+ blob (\S*)/
          blob = $1
        end
      end
    end
    content = nil
    if( blob )
      content = `git-show #{blob.inspect}`
    else
      content = File.read(file)
    end

    haml <<-HAML
%html
  %body
    ~ navigation
    %small
      :markdown
        #{text ? "This is #{text}" : ""}
    %form{:method=>'POST'}
      %textarea{:cols=>100, :rows=>40, :name=>'content'}
        :preserve
          \#{html_escape #{content.inspect}}
      %input{:type=>'submit', :value=>'sumbit'}
      %br
#{history}
    HAML
  end

  def save(filename)
    authorize
    File.open(filename, "w"){|f| f.print(params[:content])}
    `git add #{filename.inspect}`
    message = "potato edit by " + request.cookies['name']
    `git commit -m #{message.inspect}`
  end

  def authorize()
    if(MD5.hexdigest(request.cookies['password'].to_s) != $secret2)
      redirect '/pancake'
    end
  end
end
