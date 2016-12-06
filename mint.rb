require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/content_for'
require 'tilt/erubis'
require 'rack'
require 'yaml'
require 'bcrypt'
require 'pry'

configure do
  enable :sessions
  set :session_secret, 'super secret'
end

before do
  session[:incomes] ||= { "salary" => 5000 }
  session[:expenses] ||= {}
  session[:assets] ||= {}
  session[:liabilities] ||= {}
end

def calculate(category)
  category.empty? ? 0 : category.values.map(&:to_i).reduce(:+)
end

get '/' do
  @incomes = calculate(session[:incomes])
  @expenses = calculate(session[:expenses])
  @assets = calculate(session[:assets])
  @liabilities = calculate(session[:liabilities])
  erb :index
end

get '/incomes' do
  erb :incomes
end

post '/incomes' do
  type = params[:type]
  amount = params[:amount]
  session[:incomes][type] = amount

  erb :incomes
end

post '/incomes/delete' do
  
end
