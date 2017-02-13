require 'sequel'
require 'pg'
require 'pry'

DB = Sequel.connect('postgres://localhost/mint')

class SequelPersistence
  def initialize(logger, name)
    @user = name
    DB.logger = logger
  end

  def current_username
    @user
  end

  def query(sql, *params)
    @logger.info "#{sql}: #{params}"
    DB.exec_params(sql, params)
  end

  def logged_in?
    !!@user
  end

  def logout
    @user = nil
  end

  def login(name)
    @user = name
  end

  def user_exist?(username)
    dataset = DB[:users].select(:name).where(name: username)
    !dataset.first.nil?
  end

  def delete_item(finance_type, id)
    DB[:finances].where(type: finance_type, id: id).delete
  end

  def correct_login?(user, password)
    dataset = DB[:users].select(:name)
    users = dataset.map { |item| item[:name] }

    if users.include? user
      verify_password(password, user)
    else
      false
    end
  end

  def create_new_user(username, password)
    password = BCrypt::Password.create(password)

    DB[:users].insert(name: username, password: password)
  end

  def add_to(finance_type, name, amount)
    user_id = retrieve_user_id
    DB[:finances].insert( user_id: user_id,
                          type: finance_type,
                          amount: amount,
                          name: name )
  end

  def load_list_data(list)
    user_id = retrieve_user_id
    list_type = DB[:finances].select_all.where(user_id: user_id, type: list)
    description = case list
                  when 'incomes'     then 'Salary, Freelance, etc.'
                  when 'expenses'    then 'Mortgage, Insurance, etc.'
                  when 'assets'      then 'Stocks, Real Estate, etc.'
                  when 'liabilities' then 'Loans, Credit Debt, etc.'
                  end

    [list_type, list.capitalize, description]
  end

  def calculate_total(type)
    user_id = retrieve_user_id
    DB[:finances].where(type: type, user_id: user_id).sum(:amount).to_i
  end

  private

  def verify_password(password, username)
    dataset = DB[:users].select(:password).where(name: username)
    BCrypt::Password.new(dataset.first[:password]) == password
  end

  def retrieve_user_id
    DB[:users].select(:id).where(name: @user).first[:id].to_i
  end
end
