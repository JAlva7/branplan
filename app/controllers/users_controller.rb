class UsersController < ApplicationController
  before_action :logged_in_user, only: [:edit, :update]
  before_action :correct_user,   only: [:edit, :update]

  def show
    @user = User.find(params[:id])
  end

  def dashboard
    @user_uni_reqs = findCompletedUniReqs()

    @user_degrees = []
    UserDegree.where(user_id: current_user.id).each do |entry|
      degree_id = entry.degree_id
      degree = Degree.find_by(id: degree_id)
      name = degree.name+" ("+degree.degree_type+")"

      percent = calculateDegreePercent(degree)

      @user_degrees.push([name, percent])
    end

    if (current_user)
      enrollment_fall_2018 = Enrollment.where(user_id: current_user.id, term_id: 4)
      enrollment_spring_2019 = Enrollment.where(user_id: current_user.id, term_id: 5)
      @courses_fall_2018 = []
      @courses_spring_2019 = []
      if enrollment_fall_2018.count != 0
        enrollment_fall_2018.each do |e|
          course = Course.find(e.course_id)
          @courses_fall_2018.push(course)
        end
      end
      if enrollment_spring_2019.count != 0
        enrollment_spring_2019.each do |e|
          course = Course.find(e.course_id)
          @courses_spring_2019.push(course)
        end
      end
    else
      redirect_to root_url
    end

    @credits = current_user.credits
    if @credits.nil?
      @credits = 0
      @credits_percent = 0
    else
      @credits_percent = (((@credits/128.0)*100).round)
    end
  end

  def findCompletedUniReqs
    reqs_hash = Hash.new
    reqs = ["UWS", "SN", "HU", "SS", "CA", "QR", "NW", "FL"]
    reqs.each do |req|
      reqs_hash[req] = 0
    end
    user_history_codes = UserCourseHistory.where(user_id: current_user.id).map { |c| c.course_code }
    user_history_codes.each do |code|
      course_id = Course.find_by(code: code).course_id
      course_reqs = CourseRequirement.where(course_id: course_id)
      # Why is c.requirement returning nil?
      course_reqs.each do |req|
        puts req.inspect
        req_type = req[:requirement]
        puts req_type
        if reqs.include? req_type
          reqs_hash[req_type] += 1
        end
      end
    end
    puts reqs_hash
    reqs_hash
  end

  def calculateDegreePercent(degree)
    num_courses = degree.cores + degree.electives
    core_array = degree.core_courses
    electives_array = degree.elective_courses
    electives_num = degree.electives
    user_history = UserCourseHistory.where(user_id: current_user.id)
    user_history_codes = user_history.map { |c| c.course_code }
    num_completed = (core_array & user_history_codes).length + (electives_array & user_history_codes).length
    (((num_completed.to_f/num_courses.to_f)*100).round)
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    if @user.save
      log_in @user
      flash[:success] = "Welcome to the BranPlan!"
      redirect_to @user
    else
      render 'new'
    end
  end

  def edit
    @user = User.find(params[:id])

    @subjects = Subject.order(:name).uniq{|subject| subject.name}

    @degrees = Degree.order(:name)

    @user_degrees = []
    UserDegree.where(user_id: current_user.id).each do |entry|
      degree_id = entry.degree_id
      degree = Degree.find_by(id: degree_id)
      name = degree.name+" ("+degree.degree_type+")"
      @user_degrees.push(name)
    end

    @course_codes = nil

    @course_history = UserCourseHistory.where(user_id: @user.id).order(:course_code)
    @course_history = @course_history.map {|x| x.course_code}
    @course_history = @course_history.paginate(:per_page => 5, page: params[:page])

    if !params[:history_code].nil?
      @course_codes = Course.order(:code).uniq {|x| x.code}
      @course_codes = @course_codes.map { |x| x.code }
      @code = params[:history_code].upcase unless params[:history_code] == ""
      search_results = []
      @course_codes.each do |code|
        if code.include? @code
          search_results.push(code)
        end
      end
      @course_codes = search_results
    end

    # @degrees = UserDegree.where(user_id: @user_id)

    if !@course_codes.nil?
      @course_codes = @course_codes - @course_history
      @course_codes = @course_codes.paginate(:per_page => 3, page: params[:page])
    end
  end

  def add_degree
    degree = params[:degree]
    name = degree.rpartition(' ').first
    type = degree.rpartition(' ').last[1...-1]
    puts name+" "+type
    degree_id = Degree.find_by(name: name, degree_type: type).id
    UserDegree.create(user_id: current_user.id, degree_id: degree_id)
  end

  def remove_degree
    degree = params[:degree]
    name = degree.rpartition(' ').first
    type = degree.rpartition(' ').last[1...-1]
    puts name+" "+type
    degree_id = Degree.find_by(name: name, degree_type: type).id
    entry = UserDegree.find_by(user_id: current_user.id, degree_id: degree_id)
    entry.destroy
  end

  def update
    @user = User.find(params[:id])
    if @user.update_attributes(user_params)
    else
      render 'edit'
    end
  end

  private

    def user_params
      params.require(:user).permit(:name, :email, :password,
                                   :password_confirmation, :credits)
    end

    # Confirms a logged-in user.
    def logged_in_user
      unless current_user
        store_location
        flash[:danger] = "Please log in."
        redirect_to login_url
      end
    end

    # Confirms the correct user.
    def correct_user
      @user = User.find(params[:id])
      redirect_to(root_url) unless @user == current_user
    end

end
