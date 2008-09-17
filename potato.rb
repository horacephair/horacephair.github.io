require "rubygems"
require "rdiscount"
BlueCloth = RDiscount
require "haml"
require "sass"
require "sinatra"


get '/' do
  $text = RDiscount.new( File.read("text.markdown") ).to_html
  $css  = Sass::Engine.new( File.read("style.sass") ).render
  $html = Haml::Engine.new( File.read("template.haml") ).to_html
  File.open("index.html","w"){|f| f.puts($html)}
  next $html
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
end
post '/ham' do
  save("template.haml")
end
post '/head' do
  save("text.markdown")
end

helpers do
  def navigation
    RDiscount.new( <<-MARKDOWN ).to_html
[content](/head)
[style](/sugar)
[layout](/ham)
    MARKDOWN
  end

  def editor(file, text = nil)
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
          \#{html_escape File.read(#{file.inspect})}
      %input{:type=>'submit', :value=>'sumbit'}
    HAML
  end

end
