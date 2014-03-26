class UploadsController < OrganizationAwareController

  before_action :set_upload, :only => [:show, :destroy, :resubmit]  
  before_filter :check_for_cancel, :only => [:create, :update]
  
  SESSION_VIEW_TYPE_VAR = 'uploads_subnav_view_type'
  
  def index

    @page_title = 'Uploads'
    @uploads = @organization.uploads

    # remember the view type
    @view_type = get_view_type(SESSION_VIEW_TYPE_VAR)
    
    respond_to do |format|
      format.html # index.html.erb
      format.json { render :json => @uploads }
    end

  end

  def show
    
    if @upload.nil?
      notify_user(:alert, "Record not found!")
      redirect_to uploads_url
      return      
    end
    
    @page_title = "Upload: #{@upload.original_filename}"
    respond_to do |format|
      format.html # show.html.erb
      format.json { render :json => @upload }
    end
    
  end

  # Reload the worksheet. This action pushes the spreadsheet back into the queue
  # to be processed
  def resubmit
    
    if @upload.nil?
      notify_user(:alert, "Record not found!")
      redirect_to uploads_url
      return      
    end
    
    # Make sure the force flag is set and that the model is set back to
    # unprocessed
    @upload.reset
    @upload.force_update = true
    @upload.save
    
    notify_user(:notice, "File was resubmitted for processing.")        
    # create a job to process this file in the background
    create_upload_process_job(@upload)
    
    respond_to do |format|
      format.html { render 'show' }
      format.json { render :json => @upload }
    end
    
  end

  def templates
    @page_title = "Download Template"
    @template_type_array = ['New', 'Update']
    
    #prepare a list of just the asset types of the current organization
    @asset_type_array = []
    AssetType.all.each do |at|
      if @organization.asset_count(at) > 0 
        @asset_type_array << at
      end
    end
  end
  
  def create_templates
    asset_event_type_ids = []
    asset_event_type_ids = params[:asset_event_type_ids].collect { |id| id.to_i } if params[:asset_event_type_ids]
    
  end
  
  def new
    
    @page_title = "Upload Spreadsheet"
    @upload = Upload.new
    
  end
  
  #
  # Create a new upload. If the current user is an admin they can set the 
  # organization owning the upload otherwise it defaults to the user's organization
  #
  def create

    @upload = Upload.new(form_params)
    @upload.user = current_user
    # Make sure we set the organization
    unless current_user.has_role? :admin
      @upload.organiztion = current_user.organization
    end
    
    respond_to do |format|
      if @upload.save
        notify_user(:notice, "File was successfully uploaded.")        
        # create a job to process this file in the background
        create_upload_process_job(@upload)

        format.html { redirect_to uploads_url }
        format.json { render :json => @upload, :status => :created, :location => @upload }
      else
        format.html { render :action => "new" }
        format.json { render :json => @upload.errors, :status => :unprocessable_entity }
      end
    end
  end

  def destroy

    if @upload.nil?
      notify_user(:alert, "Record not found!")
      redirect_to uploads_url
      return      
    end

    @upload.destroy
    notify_user(:notice, "File was successfully removed.")

    respond_to do |format|
      format.html { redirect_to(uploads_url) } 
      format.json { head :no_content }
    end
  end

  protected
  
  # Generates a background job to propcess the file
  def create_upload_process_job(upload, priority = 0)
    if upload
      job = UploadProcessorJob.new(upload.object_key)
      fire_background_job(job, priority)
    end
  end
  
  # Never trust parameters from the scary internet, only allow the white list through.
  def form_params
    params.require(:upload).permit(upload_allowable_params)
  end
  
  # Callbacks to share common setup or constraints between actions.
  def set_upload
    @upload = Upload.find_by_object_key(params[:id]) unless params[:id].nil?
  end
  
  private
  
  def check_for_cancel
    unless params[:cancel].blank?
      redirect_to uploads_url
    end
  end
  
end
