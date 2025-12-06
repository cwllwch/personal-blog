defmodule PortalWeb.PrettifierTest do
  use PortalWeb.ConnCase

  @moduledoc """
  Sorry, this file looks like shit. Unfortunately as I added the 
  pretty printer I also need to check formatting, so the results 
  all look like crap in the code, but they look ok in HTML. ¯\_(ツ)_/¯
  """

  test "GET /prettify-my-json ", %{conn: conn} do
    conn = get(conn, ~p"/prettify-my-json")
    assert html_response(conn, 200) =~ "Make this JSON pretty"
  end

  test "parsing quoteless strings in keys" do
    input = "{name: \"John Doe\", age: 28, preferences: [{theme: \"dark\"}, {lang: \"eng-us\"}]}"
    {:parsed, result} = JsonParser.Main.prettify(input)

    assert result ==
             "{\n    \"name\": \"John Doe\",\n    \"age\": 28,\n    \"preferences\": \n        [\n            {\"theme\": \"dark\"},\n            {\"lang\": \"eng-us\"}\n        ]\n}"
  end

  test "parsing quoteless strings in values" do
    input =
      "{\"name\": John Doe, \"age\": 28, \"preferences\": [{\"theme\": dark}, {\"lang\": eng-us}]}"

    {:parsed, result} = JsonParser.Main.prettify(input)

    assert result ==
             "{\n    \"name\": \"John Doe\",\n    \"age\": 28,\n    \"preferences\": \n        [\n            {\"theme\": \"dark\"},\n            {\"lang\": \"eng-us\"}\n        ]\n}"
  end

  test "parsing with square brackets around the payload" do
    input =
      "[[{\"name\": John Doe, \"age\": 28, \"preferences\": [{\"theme\": dark}, {\"lang\": eng-us}]}]]"

    {:parsed, result} = JsonParser.Main.prettify(input)

    assert result ==
             "{\n    \"name\": \"John Doe\",\n    \"age\": 28,\n    \"preferences\": \n        [\n            {\"theme\": \"dark\"},\n            {\"lang\": \"eng-us\"}\n        ]\n}"
  end

  # This one is meant to test if the algorithm can ignore the extra escapes outside of strings.
  # As it also tries to concat strings that have no quotes, unfortunately extra escapes can't be
  # discarded from inside strings - they could be part of the payload.
  test "parsing with extra escapes" do
    input =
      "{\\\\\\\"name\": John Doe, \\\\\\\"age\": 28, \\\\\\\"preferences\": [{\\\\\"theme\": dark}, {\\\\\"lang\": eng-us}]}]]"

    {:parsed, result} = JsonParser.Main.prettify(input)

    assert result ==
             "{\n    \"name\": \"John Doe\",\n    \"age\": 28,\n    \"preferences\": \n        [\n            {\"theme\": \"dark\"},\n            {\"lang\": \"eng-us\"}\n        ]\n}"
  end

  # Lists
  test "parse simple int list" do
    input = "{key: val, list: [1, 2, 3]}"
    {:parsed, result} = JsonParser.Main.prettify(input)

    assert result ==
             "{\n    \"key\": \"val\",\n    \"list\": [1, 2, 3]\n}"
  end

  test "parse simple string list" do
    input = "{key: val, list: [\"XML\", \"JSON\", \"CSV\"]}"
    {:parsed, result} = JsonParser.Main.prettify(input)

    assert result ==
             "{\n    \"key\": \"val\",\n    \"list\": [\"XML\", \"JSON\", \"CSV\"]\n}"
  end

  # This one is an official JSON.org example
  # If it passes, we should be able to parse most stuff!
  test "parse map of maps" do
    input =
      "{\"menu\": {\"id\": \"file\", \"value\": \"File\", popup: {\"menuitem\": [ {\"value\": \"New\", \"onclick\":\"CreateNewDoc()\"},{\"value\": \"Open\", \"onclick\": \"OpenDoc()\"}, {\"value\": \"Close\", \"onclick\": \"CloseDoc()\"}]}}}"

    {:parsed, result} = JsonParser.Main.prettify(input)

    assert result ==
             "{\n    \"menu\": {\"id\": \"file\", \"value\": \"File\", \"popup\": {\n        \"menuitem\": \n        [\n            {\"menuitem\": {\"value\": \"New\", \"onclick\": \"CreateNewDoc()\"}},\n            {\"menuitem\": {\"value\": \"Open\", \"onclick\": \"OpenDoc()\"}},\n            {\"menuitem\": {\"value\": \"Close\", \"onclick\": \"CloseDoc()\"}}\n        ]\n    }\n}\n}"
  end
end
