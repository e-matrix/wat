# -*- encoding : utf-8 -*-

class PagesController < ApplicationController

  before_filter :parse_search_param, only: [:index]

  def index
    unless can_read?("Admin")
      redirect_to root_path, :alert => t(:access_denied)
    else
      @pages ||= Page.asc(:title)
    end
  end
  
  def show
    begin
      @page = Page.find(params[:id])
    rescue => e
      @page = nil
    end
  end

  def new
    @page = Page.new permalink: ''
  end

  def create
    if params[:commit] == t(:cancel)
      redirect_to root_path, :notice => t(:canceled)
    elsif !can_write?('Admin')
      redirect_to root_path, :alert => t(:access_denied)
    else
      @page = Page.create(params[:page])
      if @page.valid?
        redirect_to @page, :notice => t(:page_successfully_created)
      else
        render :new
      end
    end
  end

  def edit
    @page = Page.find(params[:id])
    unless can_write?('Admin')
      redirect_to @page, :alert => t(:you_not_allowed_to_edit_this_page)
    end
  end

  def update
    @page = Page.find(params[:id])
    if params[:commit] == t(:cancel)
      redirect_to @page, :notice => t(:nothing_changed)
      return
    end
    
    unless can_write?('Admin')
      redirect_to @page, :alert => t(:you_not_allowed_to_edit_this_page)
    else
      if @page.update_attributes(params[:page])
        redirect_to @page, :notice => t(:page_successfully_updated)
      else
        render :edit
      end
    end
  end

  def destroy
    @page = Page.find(params[:id])
    unless can_execute?('Admin')
      redirect_to @page, :notice => t(:access_denied)
    else
      @page.delete
      redirect_to root_path, :notice => t(:page_successfully_deleted)
    end
  end

  def translate_to
    session[:locale] = params[:locale].to_sym
    redirect_to edit_page_path(params[:page_id], t(:language_changed_to, :lang => params[:locale]))
  end

  def read_translation_of
    @page = Page.find(params[:page_id])
    I18n.locale = params[:locale].to_sym
    render action: :show
  end

private
  def parse_search_param
    if params[:search].present?
      _p = params[:search].is_a?(String) ? JSON.parse( params[:search] ) : params[:search]
      @search = Search.new( search_text: _p['search_text'], search_controller: _p['search_controller'] )
      @pages = Page.any_of(
        {title: /#{@search.search_text}/i}, 
        {body: /#{@search.search_text}/i}
      ).asc(:title)
    else
      @search = Search.new search_text: '', search_controller: 'pages'
    end
  end      

end
