class PdfExportJob < ApplicationJob
  queue_as :pdf_export

  def perform(project_id, file_path, user_id)
    # Full implementation in US-043
  end
end
