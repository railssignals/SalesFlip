class DeletedItemsController < ApplicationController

  before_filter :admin_required
  before_filter :resource, :only => [ :update, :destroy ]

  def index
    @items ||= [
      Lead.permitted_for(current_user).where(:deleted_at.ne => nil) +
      Contact.permitted_for(current_user).where(:deleted_at.ne => nil) +
      Account.permitted_for(current_user).where(:deleted_at.ne => nil) +
      Comment.permitted_for(current_user).where(:deleted_at.ne => nil)
    ].flatten.sort_by(&:deleted_at)
  end

  def update
    @item.update_attributes :deleted_at => nil
    redirect_to deleted_items_path
  end

  def destroy
    @item.destroy_without_paranoid
    return_to_or_default deleted_items_path
  end

protected
  def resource
    @item ||= Lead.first(:conditions => { :id => params[:id] })
    @item ||= Contact.first(:conditions => { :id => params[:id] })
    @item ||= Account.first(:conditions => { :id => params[:id] })
  end
  
  def admin_required
    raise CanCan::AccessDenied unless current_user.role_is?('Administrator')
  end
end