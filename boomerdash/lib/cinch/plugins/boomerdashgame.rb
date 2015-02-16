require 'cinch'

require_relative 'game'

module Cinch
  module Plugins

    class Boomerdashgame
      include Cinch::Plugin

      def initialize(*args)
        super
        @active_game = Game.new
        @channel_name = config[:channel]
      end

      match /join/i, :method => :join
      match /leave/i, :method => :leave
      match /start/i, :method => :start

      match /ask (.+)/i, :method => :ask
      match /answer (.+)/i, :method => :answer
      match /reject (.+)/i, :method => :reject
      match /review/i, :method => :review
      match /acceptall/i, :method => :startvote

      match /vote (.*)/i, :method => :vote
      match /status/i, :method => :status

      match /help/i, :method => :help
      match /rules/i, :method => :rules

      match /forcereset/i, :method => :forcereset
      match /allvote/i, :method => :allvote

      def help(m)
        User(m.user).send '----------------'
        User(m.user).send '!help to see this help screen'
        User(m.user).send '!rules to see this help screen'
        User(m.user).send '!join to join a game'
        User(m.user).send '!leave to leave a game'
        User(m.user).send '!start to start a game'
        User(m.user).send '----------------'
        User(m.user).send '!answer [answer] to submit/resubmit an answer'
        User(m.user).send '!vote [answer] to vote for another player\'s answer'
        User(m.user).send '----------------'
        User(m.user).send '!ask [question] to ask a question.'
        User(m.user).send '!reject [player] to reject a player\'s answer'
        User(m.user).send 'Use !review to review current answers'
        User(m.user).send 'Use !acceptall to accept/show all other answers'
        User(m.user).send '----------------'
      end

      def rules(m)
        User(m.user).send '----------------'
        User(m.user).send 'The starter player asks a question about their own life or something else'
        User(m.user).send 'Then, everyone (including the starter player) submits an answer.'
        User(m.user).send 'The starter player submits the right answer and everyone else submits a wrong answer.'
        User(m.user).send 'If anyone else submits a duplicate or the right answer, the starter player can reject it.'
        User(m.user).send 'They resubmit, and when everyone has an answer in, the starter player accepts all the answers'
        User(m.user).send '----------------'
        User(m.user).send 'Then non-starter players secretly vote. Each player gets 1 point per vote.'
        User(m.user).send 'Players who voted for the correct answer get a bonus point.'
        User(m.user).send 'Play until everyone has asked a question. Most points wins!'
        User(m.user).send '----------------'
      end

      def join(m)
        if Channel(@channel_name).has_user?(m.user)
          if @active_game.started
            User(m.user).send 'Game already started'
          else
            @active_game.add_user(m.user)
            Channel(@channel_name).send " #{m.user.nick} joined. Game now has #{@active_game.players_joined} player(s)."
          end
        else
          User(m.user).send "You need to be in #{@channel_name}."
        end
      end

      def leave(m)
        if Channel(@channel_name).has_user?(m.user)
          if @active_game.started
            User(m.user).send 'Game already started'
          else
            @active_game.remove_user(m.user)
            Channel(@channel_name).send "#{m.user.nick} left. Game now has #{@active_game.players_joined} player(s)."
          end
        end
      end

      def start(m)
        if @active_game.started
          User(m.user).send 'Game has started already'
        elsif @active_game.players_joined<3
          User(m.user).send 'Need 3 or more players to start'
        else
          @active_game.setup_game

          self.start_round
        end
      end

      def start_round
        if @active_game.round_num>=@active_game.user_hash.length || @active_game.remaining_starter_players.empty?
          Channel(@channel_name).send "That was the last round! Type !join to play again."
          self.reset_game
          return
        end
        starter_name=@active_game.remaining_starter_players.shift
        @active_game.starter_user=@active_game.user_hash[starter_name]

        if @active_game.round_num==0
          Channel(@channel_name).send "Game has started with #{@active_game.playing_user_names.join(', ')}."
          start_player=@active_game.starter_user.nick
          Channel(@channel_name).send "#{start_player} was randomly chosen to start."
        end

        @active_game.round_num+=1
        @active_game.votes=Hash.new("")
        @active_game.ordered_responses=[]#responses rae set to "" below
        @active_game.phase=:ask
        Channel(@channel_name).send "Starting round #{@active_game.round_num} with #{@active_game.starter_user.nick}"
        @active_game.playing_user_names.shuffle.each_with_index { |in_name, index|
          @active_game.name_to_renum[in_name]=index
          @active_game.ordered_responses[index]=""
        }

        @active_game.user_hash.values.each do |single_user|
          if single_user == @active_game.starter_user
            User(single_user).send 'Use !ask [question] to ask a question.'
            User(single_user).send 'Use !answer [answer] to submit the right answer'
            User(single_user).send 'Use !reject [player] to reject a player\'s answer'
            User(single_user).send 'Use !review to review current answers'
            User(single_user).send 'Use !acceptall to accept/show all other answers'
            #User(single_user).send 'Use !vote [answer] to vote for another player\'s answer'
          else
            User(single_user).send 'Use !answer [answer] to submit/resubmit a wrong answer'
            User(single_user).send 'Use !vote [answer] to vote for another player\'s answer'
          end
        end

      end

      def ask(m, question)
        if @active_game.user_in_started_game?(m.user)
          unless m.user==@active_game.starter_user
            User(m.user).send 'Only the starter may ask a question'
            return
          end
          unless @active_game.phase==:ask
            User(m.user).send 'No questions can be submitted now.'
            return
          end
          question=question.slice(0, 50) if question.length>50
          log_message="#{m.user.nick} asks #{question}"
          Channel(@channel_name).send log_message
          @active_game.question_answer_log.push(log_message)
          @active_game.phase=:answer
        end
      end

      def answer(m, input_response)
        if @active_game.user_in_started_game?(m.user)
          unless @active_game.phase==:answer
            User(m.user).send 'No answers can be submitted now.'
            return
          end
          input_response=input_response.slice(0, 50) if input_response.length>50
          self.set_response_for_name(m.user.nick, input_response)
          if m.user==@active_game.starter_user
            User(@active_game.starter_user).send("You submitted #{input_response}")
          else
            User(@active_game.starter_user).send("#{m.user.nick} submitted #{input_response}")
          end
        end
      end

      def review(m)
        if @active_game.user_in_started_game?(m.user)
          unless m.user==@active_game.starter_user
            User(m.user).send 'Only the starter may review answers before voting'
            return
          end
          @active_game.playing_user_names.each { |name|
            name_response=self.response_for_name(name)
            User(m.user).send "#{name} answered #{name_response}" #if name_response.length>0
          }
        end
      end

      def reject(m, raw_target_name)
        if @active_game.user_in_started_game?(m.user)
          unless m.user==@active_game.starter_user
            User(m.user).send 'Only the starter may reject answers before voting'
            return
          end
          target_name=@active_game.correct_caps_players(raw_target_name)
          if target_name
            if response_for_name(target_name)==""
              User(m.user).send "#{target_name} doesn't have an answer submitted."
            else
              User(@active_game.user_hash[target_name]).send "Your answer #{self.response_for_name(target_name)} was rejected."
              User(m.user).send "You rejected an answer from #{target_name}"
              self.set_response_for_name(target_name, "")
            end
          else
            User(m.user).send "Don't know who #{raw_target_name} is."
          end
        end
      end


      def startvote(m)
        if @active_game.user_in_started_game?(m.user)
          if m.user!=@active_game.starter_user
            User(m.user).send 'Only the starter may start voting'
            return
          elsif @active_game.phase!=:answer
            User(m.user).send 'Voting can only start after answers were submitted'
            return
          elsif @active_game.ordered_responses.any? { |response| response=="" }
            User(m.user).send 'Not everyone has submitted an answer. Type !status for status'
          else
            @active_game.phase=:vote
            Channel(@channel_name).send "==Responses=="
            @active_game.ordered_responses.each_with_index { |input_response, index|
              Channel(@channel_name).send "#{index} | #{input_response}"
            }
            Channel(@channel_name).send "Use !vote [number] to vote for a response"
          end
        end
      end


      def vote(m, number)
        if @active_game.user_in_started_game?(m.user)
          if @active_game.phase==:vote
            if ! @active_game.variant?(:allvote) && m.user==@active_game.starter_user
              User(m.user).send 'The starter player doesn\'t vote except when using the allvote variant'
              return
            end

            vote_choice=number.to_i
            vote_choice=0 if vote_choice<0 or vote_choice>=@active_game.user_hash.size
            if @active_game.name_to_renum[m.user.nick]==vote_choice
              User(m.user).send 'You can\'t vote for your own'
              return
            end
            @active_game.votes[m.user.nick]=number.to_i
            if @active_game.all_votes_in?
              self.check_votes
            else
              User(m.user).send "You voted #{vote_choice} #{@active_game.ordered_responses[vote_choice]}"
            end
          else
            User(m.user).send 'Unable to vote at this time'
          end
        end
      end

      def status(m)
        if @active_game.user_in_started_game?(m.user)
          if @active_game.phase == :ask
            User(m.user).send "Waiting for a question from #{@active_game.starter_user.nick}"
          elsif @active_game.phase==:answer
            remaining_voters=@active_game.playing_user_names.select { |user_name| self.response_for_name(user_name)=="" }
            User(m.user).send "Waiting on #{remaining_voters.join(', ')} to answer."
          elsif @active_game.votes.empty?
            User(m.user).send "No votes have been cast yet"
          else
            remaining_voters=@active_game.playing_user_names.reject { |user_name| @active_game.votes.keys.include?(user_name) }
            User(m.user).send "Waiting on #{remaining_voters.join(', ')} to vote."
          end
        end
      end

      def unvote(m)
        if @active_game.player_during_vote_phase?(m.user.nick)
          @active_game.votes.delete(m.user.nick)
          User(m.user).send 'Vote removed'
        end
      end

      def check_votes
        bonus_points=1 #constant bonus for correct response
        @active_game.phase=:end #this should change to ask later on
        starter_name=@active_game.starter_user.nick
        correct_response_index=@active_game.name_to_renum[starter_name]
        @active_game.question_answer_log.push("Correct answer: #{@active_game.ordered_responses[correct_response_index]}")

        correct_players=@active_game.playing_user_names.select {|name|
          @active_game.votes[name]==correct_response_index
        }
        correct_players.each { |name|
          @active_game.scores_hash[name]+=bonus_points
        }

        counts=Hash.new(0)

        Channel(@channel_name).send "Correct: #{correct_response_index} #{@active_game.ordered_responses[correct_response_index]}: #{correct_players.join(', ')}"
        Channel(@channel_name).send "=========================="

        @active_game.playing_user_names.each { |name|
          chosen_index=@active_game.name_to_renum[name]
          chosen_by_names=@active_game.playing_user_names.select { |possible_name| @active_game.votes[possible_name]==chosen_index}
          @active_game.scores_hash[name]+=chosen_by_names.length unless name==starter_name
          counts[chosen_index]=chosen_by_names.length
          Channel(@channel_name).send "#{name} (#{chosen_index}) #{@active_game.ordered_responses[chosen_index]}: #{chosen_by_names.join(', ')}"
        }

        if @active_game.variant?(:allvote) and @active_game.playing_user_names.all?{|input_name| counts[@active_game.votes[starter_name]]>=counts[@active_game.votes[input_name]]}
          @active_game.scores_hash[starter_name]+=bonus_points
        end


        Channel(@channel_name).send "=============================="
        self.show_scores
        Channel(@channel_name).send "=============================="
        self.start_round
      end


      def response_for_name(input_name)
        puts "Checking response for #{input_name}"
        response_num=@active_game.name_to_renum[input_name]
        return_response=@active_game.ordered_responses[response_num]
        puts "Response #{response_num} is #{return_response}"
        return_response
      end

      def set_response_for_name(input_name, input_response)
        puts "Setting response for #{input_name}"

        @active_game.ordered_responses[@active_game.name_to_renum[input_name]]=input_response
        response_num=@active_game.name_to_renum[input_name]
        puts "Response #{response_num} is #{@active_game.ordered_responses[@active_game.name_to_renum[input_name]]}"

      end

      def show_scores
        name_by_score=@active_game.playing_user_names.sort {|a,b| @active_game.scores_hash[b]<=> @active_game.scores_hash[a]}
        name_by_score.each { |name| Channel(@channel_name).send "#{name}: #{@active_game.scores_hash[name]}"}
      end

      def forcereset(m)
        self.reset_game
      end

      def reset_game
        @active_game=Game.new()
      end

      def allvote(m)
        if @active_game.started
          User(m.user).send "To change the variant, start a new game"
          return
        end
        @active_game.toggle_variant(:allvote)
        if @active_game.variant?(:allvote)
          Channel(@channel_name).send "Allvote on (Starter player now can vote for a popular answer)"
        else
          Channel(@channel_name).send "Allvote off (Starter player now doesn't vote)"
        end
      end
    end
  end
end