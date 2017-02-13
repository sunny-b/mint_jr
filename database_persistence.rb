require 'pg'

class DatabasePersistence
  def initialize(logger, name)
    @db = PG.connect(dbname: 'mint')
    @user = name
    @logger = logger
  end

  def current_username
    @user
  end

  def query(sql, *params)
    @logger.info "#{sql}: #{params}"
    @db.exec_params(sql, params)
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
    sql = "SELECT name FROM users WHERE name = $1"
    result = query(sql, username)

    !result.first.nil?
  end

  def delete_item(finance_type, id)
    sql = "DELETE FROM finances WHERE type = $1 AND id = $2"
    query(sql, finance_type, id)
  end

  def correct_login?(user, password)
    sql = 'SELECT name FROM users'
    users = query(sql).map { |item| item["name"] }

    if users.include? user
      verify_password(password, user)
    else
      false
    end
  end

  def create_new_user(username, password)
    password = BCrypt::Password.create(password)
    sql = 'INSERT INTO users (name, password) VALUES ($1, $2)'
    query(sql, username, password)
  end

  def add_to(finance_type, name, amount)
    sql = "INSERT INTO finances (user_id, type, amount, name) VALUES ($1, $2, $3, $4)"
    user_id = retrieve_user_id
    query(sql, user_id, finance_type, amount, name)
  end

  def load_list_data(list)
    user_id = retrieve_user_id
    sql = "SELECT * FROM finances WHERE user_id = $1 AND type = $2"
    list_type = query(sql, user_id, list)
    list_name = list.capitalize
    description = case list
                  when 'incomes'     then 'Salary, Freelance, etc.'
                  when 'expenses'    then 'Mortgage, Insurance, etc.'
                  when 'assets'      then 'Stocks, Real Estate, etc.'
                  when 'liabilities' then 'Loans, Credit Debt, etc.'
                  end

    [list_type, list_name, description]
  end

  def calculate_total(type)
    user_id = retrieve_user_id
    sql = "SELECT sum(amount) AS total FROM finances WHERE type = $1 AND user_id = $2"
    result = query(sql, type, user_id)

    result.first["total"].to_i
  end

  def expenses_total
    user_data = load_user_credentials
    user_data[current_username][:expenses]
  end

  def assets_total
    user_data = load_user_credentials
    user_data[current_username][:assets]
  end

  def liabilities_total
    user_data = load_user_credentials
    user_data[current_username][:liabilities]
  end

  private

  def verify_password(password, username)
    sql = 'SELECT password FROM users WHERE name = $1'
    result = query(sql, username)

    BCrypt::Password.new(result.first["password"]) == password
  end

  def retrieve_user_id
    sql = 'SELECT id FROM users WHERE name = $1'
    query(sql, @user).first["id"].to_i
  end
end
