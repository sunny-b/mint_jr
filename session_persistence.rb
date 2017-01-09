class SessionPersistence
  def initialize(session)
    @session = session
    @session[:username] ||=nil
  end

  def logged_in?
    !!@session[:username]
  end

  def logout
    @session[:username] = nil
  end

  def login(name)
    @session[:username] = name
  end

  def user_exist?(username)
    user_data = load_user_credentials
    user_data.key?(username)
  end

  def delete_item(finance_type, id)
    user_data = load_user_credentials
    user_info = user_data[current_username][finance_type]
    user_info.reject! { |item| item[:id] == id }
    update_user_info(user_data)
  end

  def correct_login?(user, password)
    users = load_user_credentials
    if users.key? user
      BCrypt::Password.new(users[user][:password]) == password
    else
      false
    end
  end

  def create_new_user(username, password)
    user_data = load_user_credentials

    user_data[username] = {}
    password = BCrypt::Password.create(password)
    user_data[username][:password] = password
    user_data[username][:incomes] = []
    user_data[username][:expenses] = []
    user_data[username][:assets] = []
    user_data[username][:liabilities] = []

    update_user_info(user_data)
  end

  def add_to(finance_type, type, amount)
    user_data = load_user_credentials
    finances = user_data[current_username][finance_type]

    finances << { type: type,
                  amount: amount,
                  id: next_id(finances) }

    update_user_info(user_data)
  end

  def load_list_data(list)
    user_data = load_user_credentials
    list_type = user_data[current_username][list.to_sym]
    list_name = list.capitalize
    description = case list
                  when 'incomes'     then 'Salary, Freelance, etc.'
                  when 'expenses'    then 'Mortgage, Insurance, etc.'
                  when 'assets'      then 'Stocks, Real Estate, etc.'
                  when 'liabilities' then 'Loans, Credit Debt, etc.'
                  end

    [list_type, list_name, description]
  end

  def update_user_info(data)
    credentials = if ENV['RACK_ENV'] == 'test'
                    File.expand_path('../test/users.yml', __FILE__)
                  else
                    File.expand_path('../users.yml', __FILE__)
                  end
    File.open(credentials, 'wb') { |file| YAML.dump(data, file) }
  end

  def load_user_credentials
    credentials = if ENV['RACK_ENV'] == 'test'
                    File.expand_path('../test/users.yml', __FILE__)
                  else
                    File.expand_path('../users.yml', __FILE__)
                  end
    YAML.load_file(credentials)
  end

  def incomes
    user_data = load_user_credentials
    user_data[current_username][:incomes]
  end

  def expenses
    user_data = load_user_credentials
    user_data[current_username][:expenses]
  end

  def assets
    user_data = load_user_credentials
    user_data[current_username][:assets]
  end

  def liabilities
    user_data = load_user_credentials
    user_data[current_username][:liabilities]
  end

  private

  def next_id(elements)
    max = elements.map { |element| element[:id] }.max || 0
    max + 1
  end

  def current_username
    @session[:username]
  end
end
