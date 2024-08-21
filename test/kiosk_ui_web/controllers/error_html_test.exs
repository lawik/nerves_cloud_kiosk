defmodule KioskWeb.ErrorHTMLTest do
  use KioskWeb.ConnCase, async: true

  # Bring render_to_string/4 for testing custom views
  import Phoenix.Template

  test "renders 404.html" do
    assert render_to_string(KioskWeb.ErrorHTML, "404", "html", []) == "Not Found"
  end

  test "renders 500.html" do
    assert render_to_string(KioskWeb.ErrorHTML, "500", "html", []) == "Internal Server Error"
  end
end
