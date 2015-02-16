require 'cinch'
require './boomerdash/lib/cinch/plugins/boomerdashgame.rb'

bot = Cinch::Bot.new do

  configure do |c|
    c.nick            = "boomerdashbot"
    c.server          = "chat.freenode.net"
    c.channels        = ["#playboomerdash"]
    c.verbose         = true
    c.plugins.plugins = [
        Cinch::Plugins::Boomerdashgame
    ]
    c.plugins.options[Cinch::Plugins::Boomerdashgame] = {
        :mods     => ["contig"],
        :channel  => "#playboomerdash",
#        :settings => "settings.yml"
    }
  end

end

bot.start
