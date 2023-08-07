defmodule Noizu.Intellect.Module.HtmlModuleTest do
  use ExUnit.Case, async: false
  @moduletag lib: :noizu_intellect_module
  import Noizu.Intellect.HtmlModule

  def delivery_details_happy_path() do
    """
    <monitor-response>
      message_details:
        replying_to:
          - message:
            for: 123401
            confidence: 42
            explanation: "Apple Bapple"
            complete: true
            completed_by: 532
          - message:
            for: 123501
            confidence: 43
            explanation: "BApple Snapple"
          - message:
            for: 123601
            confidence: 43
      audience:
        - member:
          for: 111102
          confidence: 33
          explanation: "Henry"
        - member:
          for: 111202
          confidence: 44
          explanation: "Ford"
      summary:
        content: "Brief Details."
        features:
          - "AAA"
          - "BBB"
    </monitor-response>
    """
  end




  def valid_response() do
    """

    <mark-read for="1,2,3,4,5"/>
    <reply for="6,7">
      <nlp-intent>
      I will do a thing
      </nlp-intent>
      <response>My actual response</response>
      <nlp-reflect>
      My Reflection on my response.
      </nlp-reflect>
    </reply>
    <reply for="8,9">
      <nlp-intent>
      Another Intent
      </nlp-intent>
      <response>Another response</response>
      <nlp-reflect>
      More Reflections
      </nlp-reflect>
    </reply>
    """
  end

  def malformed_response() do
  """
  Ignore this
  <mark-read for="1,2,3,4,5"/>
  Ignore this as well
  <reply for="6,7">
    <nlp-intent>
    I will do a thing
    </nlp-intent>
    <response>My actual response</response>
    <nlp-reflect>
    My Reflection on my response.
    </nlp-reflect>
  </reply>
  <reply for="8,9">
    <nlp-intent>
    Another Intent
    </nlp-intent>
    <response>Another response</response>
    <nlp-reflect>
    More Reflections
    </nlp-reflect>
  </reply>
  Ignore this as well
  <unexpected>Ignore this</unexpected>
  """
  end

  describe "yaml parsing suite" do

    test "should convert map to yaml" do
      map = %{a: 1, b: 2, c: 3}
      assert to_yaml(map) == """
             a: 1
             b: 2
             c: 3
             """
    end

    test "should convert nested map to yaml" do
      map = %{a: %{b: 1, c: 2}, d: 3}
      assert to_yaml(map) == """
             a:
               b: 1
               c: 2
             d: 3
             """
    end

    test "should convert list to yaml" do
      list = [1, 2, 3]
      assert to_yaml(list) == """
             - 1
             - 2
             - 3
             """
    end

    test "should convert nested list to yaml" do
      list = [1, [2, 3], 4]
      assert to_yaml(list) == """
             - 1
             - - 2
               - 3
             - 4
             """
    end

    test "should convert complex data structure to yaml" do
      data = %{a: [1,2,3,4], b: [%{c: 1, d: 2}, %{c: [5, %{beta: 7, zeta: 8, mecka: [1,2,3]}, "apple"], d: 5}, "hey"], f: "apple aple\n apple"}

      assert to_yaml(data) == """
             a:
               - 1
               - 2
               - 3
               - 4
             b:
               - c: 1
                 d: 2
               - c:
                   - 5
                   - beta: 7
                     mecka:
                       - 1
                       - 2
                       - 3
                     zeta: 8
                   - apple
                 d: 5
               - hey
             f: |-
               apple aple
                apple
             """
    end
  end

  describe "Handle Message Delivery Response" do
    @tag :wip
    test "happy path" do
      sut = Noizu.Intellect.HtmlModule.extract_message_delivery_details(delivery_details_happy_path)
      assert sut == [
               audience: {111102, 33, "Henry"},
               audience: {111202, 44, "Ford"},
               responding_to: {123401, 42, {true, 532}, "Apple Bapple"},
               responding_to: {123501, 43, {nil, nil}, "BApple Snapple"},
               responding_to: {123601, 43, {nil, nil}, nil},
               summary: {"Brief Details.", ["AAA", "BBB"]}
             ]
    end
  end

  test "extract_response_sections - valid" do
    {:ok, response} = Noizu.Intellect.HtmlModule.extract_response_sections(valid_response())
    valid? = Noizu.Intellect.HtmlModule.valid_response?(response)
    assert valid? == :ok
    response = Enum.group_by(response, &(elem(&1, 0)))

    [ack] = response.ack
    assert ack == {:ack, [ids: [1,2,3,4,5]]}
    [reply_one, reply_two] = response.reply
    assert reply_one == {:reply, [ids: [6,7], intent: "I will do a thing", response: "My actual response", reflect: "My Reflection on my response."]}
    assert reply_two == {:reply, [ids: [8,9], intent: "Another Intent", response: "Another response", reflect: "More Reflections"]}
  end

  test "extract_response_sections - malformed but repairable" do
    {:ok, response} = Noizu.Intellect.HtmlModule.extract_response_sections(malformed_response())
    valid? = Noizu.Intellect.HtmlModule.valid_response?(response)
    assert valid? != :ok
    assert valid? == {:issues, [invalid_section: {:text, "Ignore this"}, invalid_section: {:text, "Ignore this as well"}, invalid_section: {:text, "Ignore this as well"}, invalid_section: {:other, {"unexpected", [], ["Ignore this"]}}]}
    {:ok, repair} = Noizu.Intellect.HtmlModule.repair_response(response)
    repair = Enum.group_by(repair, &(elem(&1, 0)))

    [ack] = repair.ack
    assert ack == {:ack, [ids: [1,2,3,4,5]]}
    [reply_one, reply_two] = repair.reply
    assert reply_one == {:reply, [ids: [6,7], intent: "I will do a thing", response: "My actual response", reflect: "My Reflection on my response."]}
    assert reply_two == {:reply, [ids: [8,9], intent: "Another Intent", response: "Another response", reflect: "More Reflections"]}
  end

  test "extract_meta_data" do

  end

end
