defmodule PortalWeb.PrettifierTest do
  use PortalWeb.ConnCase

  test "GET /prettify-my-json ", %{conn: conn} do
    conn = get(conn, ~p"/prettify-my-json")
    assert html_response(conn, 200) =~ "Make this JSON pretty"
  end

  test "parsing quoteless strings in keys" do
    input = "{name: \"John Doe\", age: 28, preferences: [{theme: \"dark\"}, {lang: \"eng-us\"}]}"
    result = JsonParser.Main.prettify(input)

    assert result ==
             {:parsed,
              "{\"name\": \"John Doe\",\n \"age\": 28,\n \"preferences\": [\n\n, ,\n {\"theme\": \"dark\"},\n {\"lang\": \"eng-us\"}\n]\n}"}
  end

  test "parsing quoteless strings in values" do
    input =
      "{\"name\": John Doe, \"age\": 28, \"preferences\": [{\"theme\": dark}, {\"lang\": eng-us}]}"

    result = JsonParser.Main.prettify(input)

    assert result ==
             {:parsed,
              "{\"name\": \"John Doe\",\n \"age\": 28,\n \"preferences\": [\n\n, ,\n {\"theme\": \"dark\"},\n {\"lang\": \"eng-us\"}\n]\n}"}
  end

  test "parsing with square brackets around the payload" do
    input =
      "[[{\"name\": John Doe, \"age\": 28, \"preferences\": [{\"theme\": dark}, {\"lang\": eng-us}]}]]"

    result = JsonParser.Main.prettify(input)

    assert result ==
             {:parsed,
              "{\"name\": \"John Doe\",\n \"age\": 28,\n \"preferences\": [\n\n, ,\n {\"theme\": \"dark\"},\n {\"lang\": \"eng-us\"}\n]\n}"}
  end

  # This one is meant to test if the algorithm can ignore the extra escapes outside of strings.
  # As it also tries to concat strings that have no quotes, unfortunately extra escapes can't be
  # discarded from inside strings - they could be part of the payload.
  test "parsing with extra escapes" do
    input =
      "{\\\\\\\"name\": John Doe, \\\\\\\"age\": 28, \\\\\\\"preferences\": [{\\\\\"theme\": dark}, {\\\\\"lang\": eng-us}]}]]"

    result = JsonParser.Main.prettify(input)

    assert result ==
             {:parsed,
              "{\"name\": \"John Doe\",\n \"age\": 28,\n \"preferences\": [\n\n, ,\n {\"theme\": \"dark\"},\n {\"lang\": \"eng-us\"}\n]\n}"}
  end
end
