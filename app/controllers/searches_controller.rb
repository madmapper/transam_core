class SearchesController < OrganizationAwareController

  add_breadcrumb "Home", :root_path

  ASSET_SEARCH_TYPE             = '1'
  CAPITAL_PLAN_SEARCH_TYPE      = '2'
  ORGANIZATION_SEARCH_TYPE      = '3'
  USER_SEARCH_TYPE              = '4'
  FUNDING_SOURCE_SEARCH_TYPE    = '5'
  FUNDING_LINE_ITEM_SEARCH_TYPE = '6'

  # Session Variables
  INDEX_KEY_LIST_VAR        = "search_key_list_cache_var"
  
  MAX_ROWS_RETURNED = SystemConfig.instance.max_rows_returned

  # Set the view variables form the params @search_type, @searcher_klass
  before_filter :set_view_vars,     :only => [:create, :new]

  def create

    @searcher = @searcher_klass.constantize.new(params[:searcher])
    @searcher.user = current_user
    @data = @searcher.data

    add_breadcrumb "Search"
    add_breadcrumb "Results"

    # Cache the result set so the use can page through them
    unless @searcher.cache_variable_name.blank?
      cache_list(@data, @searcher.cache_variable_name)
    end

    respond_to do |format|
      format.html { render 'new' }
      format.js   { render 'new' }
      format.json { render :json => @data }
    end

  end

  # Render the inventory search form
  def new

    @searcher = @searcher_klass.constantize.new
    @searcher.user = current_user
    @data = []

    add_breadcrumb "Search"

    respond_to do |format|
      format.html # new.html.erb
    end
  end

  # Action for performiong full text search unsing the search text index
  def keyword

    @search_text = params["search_text"]

    add_breadcrumb "Keyword Search: '#{@search_text}'"

    #testing w "981ECCHHGG58 981ECCD92F8E"
    # 982596NN025M D1254
    #console stuff
    #results = KeywordSearchIndex.where("search_text like '%D1254%'")
    #

    search_criteria = ""
    @search_text.split(" ").each_with_index {|search_string, search_string_index|
      if search_string.length > 3
        if search_criteria.length == 0
          search_criteria =  " search_text like '%#{search_string}%'"
        else
          search_criteria += " OR search_text like '%#{search_string}%'"
        end
      end
    }

    @keyword_search_results = KeywordSearchIndex.where(search_criteria).limit(MAX_ROWS_RETURNED)
    cache_list(@keyword_search_results, INDEX_KEY_LIST_VAR)

    respond_to do |format|
      format.html
      format.json { render :json => @keyword_search_results }
    end

  end

  protected

  def set_view_vars

    add_breadcrumb "Home", root_path

    @search_type = params[:search_type]
    if @search_type == ASSET_SEARCH_TYPE
      @searcher_klass = "AssetSearcher"
      add_breadcrumb "Assets", inventory_index_path
    elsif @search_type == CAPITAL_PLAN_SEARCH_TYPE
      @searcher_klass = "CapitalProjectSearcher"
      add_breadcrumb "Capital Projects", capital_projects_path
    elsif @search_type == ORGANIZATION_SEARCH_TYPE
      @searcher_klass = "OrganizationSearcher"
      add_breadcrumb "Organizations", organizations_path
    elsif @search_type == USER_SEARCH_TYPE
      @searcher_klass = "UserSearcher"
      add_breadcrumb "Users", users_path
    elsif @search_type == FUNDING_SOURCE_SEARCH_TYPE
      @searcher_klass = "FundingSourceSearcher"
      add_breadcrumb "Funds", funding_sources_path
    elsif @search_type == FUNDING_LINE_ITEM_SEARCH_TYPE
      @searcher_klass = "FundingLineItemSearcher"
      add_breadcrumb "Appropriations", funding_line_items_path
    else
      notify_user(:alert, "Something went wrong. Can't determine type of search to perform.")
      redirect_to root_path
      return
    end

  end

end
