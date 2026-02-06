class PdfExportJob < ApplicationJob
  queue_as :pdf_export

  def perform(project_id, file_path, user_id)
    project = Project.find(project_id)
    user = User.find(user_id)

    markdown = GitService.read_file(project, file_path).force_encoding("UTF-8")
    body_html = Commonmarker.to_html(markdown, options: {
      extension: { table: true, strikethrough: true, tasklist: true }
    })

    html = build_html_document(body_html)
    pdf_data = Grover.new(html).to_pdf

    basename = File.basename(file_path, File.extname(file_path))
    filename = "#{basename}.pdf"

    blob = ActiveStorage::Blob.create_and_upload!(
      io: StringIO.new(pdf_data),
      filename: filename,
      content_type: "application/pdf"
    )

    download_url = Rails.application.routes.url_helpers.rails_blob_path(blob, disposition: "attachment", only_path: true)

    ActionCable.server.broadcast(
      "user:#{user.id}:notifications",
      { type: "pdf_ready", filename: filename, download_url: download_url }
    )
  end

  private

  def build_html_document(body_html)
    <<~HTML
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <style>
          body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
            line-height: 1.6;
            color: #1a1a1a;
            max-width: 800px;
            margin: 0 auto;
            padding: 20px;
          }
          h1 { font-size: 2em; margin-top: 0.5em; margin-bottom: 0.5em; border-bottom: 1px solid #eee; padding-bottom: 0.3em; }
          h2 { font-size: 1.5em; margin-top: 0.5em; margin-bottom: 0.5em; border-bottom: 1px solid #eee; padding-bottom: 0.3em; }
          h3 { font-size: 1.25em; }
          code { background: #f4f4f4; padding: 0.2em 0.4em; border-radius: 3px; font-size: 0.9em; }
          pre { background: #f4f4f4; padding: 1em; border-radius: 6px; overflow-x: auto; }
          pre code { background: none; padding: 0; }
          blockquote { border-left: 4px solid #ddd; margin-left: 0; padding-left: 1em; color: #666; }
          table { border-collapse: collapse; width: 100%; margin: 1em 0; }
          th, td { border: 1px solid #ddd; padding: 8px 12px; text-align: left; }
          th { background: #f4f4f4; font-weight: 600; }
          img { max-width: 100%; height: auto; }
          a { color: #0366d6; }
        </style>
      </head>
      <body>
        #{body_html}
      </body>
      </html>
    HTML
  end
end
