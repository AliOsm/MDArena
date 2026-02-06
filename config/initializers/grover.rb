Grover.configure do |config|
  config.options = {
    format: "A4",
    margin: {
      top: "1cm",
      bottom: "1cm",
      left: "1.5cm",
      right: "1.5cm"
    },
    print_background: true,
    launch_args: Rails.env.development? ? [ "--no-sandbox" ] : [],
    browser_ws_endpoint: Rails.env.development? ? "ws://localhost:3333" : nil
  }.compact
end
