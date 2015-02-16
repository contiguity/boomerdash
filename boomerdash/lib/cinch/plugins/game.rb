class Game
  attr_accessor :phase, :user_hash, :playing_user_names, :started, :starter_user, :votes_needed, :ordered_responses, :name_to_renum, :votes, :variants, :question_answer_log, :round_num, :scores_hash, :remaining_starter_players

  def initialize
    self.phase=:none
    self.user_hash = {}
    self.playing_user_names=[]
    self.started = false
    self.starter_user=nil
    self.votes_needed=0
    self.name_to_renum={}
    self.ordered_responses=[]
    self.votes=Hash.new("")
    self.variants=[] #finalguess, noaccuse
    self.question_answer_log=[]
    self.round_num=0
    self.scores_hash=Hash.new(0)
    self.remaining_starter_players=[]
  end

  #add status -- game hasn't started, questioning phase, waiting on __ (accuse phase), waiting on spy to guess location

  def add_user(user)
    user_hash[user.nick]=user unless user_hash.has_key?(user.nick)
  end

  def remove_user(user)
    user_hash.delete(user.nick)
  end

  def setup_game
    self.started=true
    self.phase=:ask
    self.playing_user_names=self.user_hash.keys.shuffle
    self.remaining_starter_players=self.playing_user_names.dup
    if self.variants.include?(:allvote)
      self.votes_needed=self.playing_user_names.length #everyone must enter a response
    else
      self.votes_needed=self.playing_user_names.length-1 #everyone must enter a response, except starter player
    end
  end

  def all_votes_in?
    puts '==Current votes =='
    puts self.votes
    self.votes.size==self.votes_needed
    #return
  end

  def correct_caps_players(player_name) #returns nil if none
    self.playing_user_names.select{|list_name| player_name.casecmp(list_name)==0}.first
  end

  def player_during_vote_phase?(player_name)
    self.started && self.playing_user_names.include?(player_name) && self.phase==:vote
  end

  #def player_during_accusing_phase?(player_name)
  #  self.started && self.playing_user_names.include?(player_name) && self.phase==:accusing
  #end

  def user_in_started_game?(input_user)
    self.started && self.playing_user_names.include?(input_user.nick)
  end

  def players_joined
    self.user_hash.length
  end

  def toggle_variant(input_variant)
    on_after=!self.variants.include?(input_variant)
    if on_after
      self.variants.push(input_variant)
    else
      self.variants.delete(input_variant)
    end
  end

  def variant?(input_variant)
    self.variants.include?(input_variant)
  end
end
