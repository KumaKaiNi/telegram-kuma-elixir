defmodule KumaBot.Bot do
  use KumaBot.Module
  import KumaBot.Util
  require Logger

  handle :text do
    rekyuu = Application.get_env(:kuma_bot, :rekyuu)

    command ["leave", "part"] do
      if message.from.id == rekyuu do
        leave_chat(message.chat.id)
      end
    end

    command "kuma" do
      Logger.warn "== DEBUG =="
      IO.inspect update
      Logger.warn "== DEBUG =="

      reply send_chat_action "record_audio"

      file = download_dep(Enum.random(kuma_replies))
      reply send_voice file
    end

    command "help" do
      reply send_message """
      First ship of the Kuma-class light cruisers, Kuma, kuma.
      Born in Sasebo, kuma. I got some old parts, but I'll try my best, kuma.

      /coin - flips a coin.
      /random - picks a random item from a list.
      /predict - sends a prediction.
      /message - random dark souls message.
      /search - returns the first DuckDuckGo result.
      /tts :Voice text - speaks what you say. Via acapela-group.
      /dan - returns a random recent image using a danbooru.
      /lewd - random nsfw danbooru post.
      /safe - random sfw danbooru post.
      /smug - sends a smug anime girl.

      Source (v3.0.0): https://github.com/KumaKaiNi/telegram-kuma-elixir
      """, [disable_web_page_preview: true]
    end

    command "botsrights" do
      reply send_message "http://reddit.com/r/botsrights"
    end

    command "dank" do
      case message do
        %{from: %{first_name: name}} ->
          reply send_message "Shut the fuck up, #{name}"
        %{from: %{username: name}} ->
          reply send_message "Shut the fuck up, @#{name}"
      end
    end

    command ["s", "find", "search"] do
      [_ | search_term] = String.split(message.text)

      reply send_chat_action "typing"

      query = search_term |> Enum.join(" ") |> URI.encode_www_form
      request = "http://api.duckduckgo.com/?q=#{query}&skip_disambig=1&no_redirect=1&no_html=1&format=json&t=KumaBot" |> HTTPoison.get!
      response = Poison.Parser.parse!((request.body), keys: :atoms)
      answer = response."Answer"

      case answer do
        "" ->
          result = response."AbstractURL"
          text = response."AbstractText"

          case result do
            "" -> reply send_message "Nothing found!"
            result ->
              case text do
                "" -> reply send_message result
                text -> reply send_message "#{text}\n\n#{result}", [disable_web_page_preview: true]
              end
          end
        answer ->
          reply send_message "#{answer}", [disable_web_page_preview: true]
      end
    end

    command "weather" do
      input = message.text |> String.split

      location = cond do
        length(input) >= 2 ->
          [_ | location] = message.text |> String.split

          cond do
            location |> List.first == "set" ->
              ["set" | location] = location
              location = location |> Enum.join(" ") |> String.split(", ") |> Enum.join(",")
              uid = message.from.id
              store_data("locations", uid, location)
              location
            true -> location |> Enum.join(" ") |> String.split(", ") |> Enum.join(",")
          end
        length(input) == 1 ->
          uid = message.from.id
          query_data("locations", uid)
        true -> nil
      end

      case location do
        nil -> reply send_message "You're not in the database. Please use `/weather set <location>` or use `/weather <location>`.", [parse_mode: "Markdown"]
        location ->
          location = location |> URI.encode_www_form
          request = "https://api.apixu.com/v1/current.json?key=#{Application.get_env(:kuma_bot, :apixu)}&q=#{location}" |> HTTPoison.get!

          w = Poison.Parser.parse!((request.body), keys: :atoms)

          case map_size(w) do
            0 -> reply send_message "Too many requests. You'll have to wait a bit."
            _ ->
              case Map.get(w, :error) do
                nil ->
                  reply send_message """
                  *Conditions for #{w.location.name}, #{w.location.region}, #{w.location.country}*

                  *Current:* #{w.current.temp_f |> round}°F / #{w.current.temp_c |> round}°C
                  *Feels like:* #{w.current.feelslike_f |> round}°F / #{w.current.feelslike_c |> round}°C

                  *Condition:* #{w.current.condition.text}
                  *Wind:* #{w.current.wind_mph} MPH / #{w.current.wind_kph} KPH #{w.current.wind_dir}
                  *Humidity:* #{w.current.humidity}%
                  """, [parse_mode: "Markdown"]
                error ->
                  reply send_message "#{error.message}"
              end
          end
      end
    end

    command "time" do
      input = message.text |> String.split

      location = cond do
        length(input) >= 2 ->
          [_ | location] = message.text |> String.split

          cond do
            location |> List.first == "set" ->
              ["set" | location] = location
              location = location |> Enum.join(" ") |> String.split(", ") |> Enum.join(",")
              uid = message.from.id
              store_data("locations", uid, location)
              location
            true -> location |> Enum.join(" ") |> String.split(", ") |> Enum.join(",")
          end
        length(input) == 1 ->
          uid = message.from.id
          query_data("locations", uid)
        true -> nil
      end

      case location do
        nil -> reply send_message "You're not in the database. Please use `/time set <location>` or use `/time <location>`.", [parse_mode: "Markdown"]
        location ->
          location = location |> URI.encode_www_form
          request = "https://api.apixu.com/v1/current.json?key=#{Application.get_env(:kuma_bot, :apixu)}&q=#{location}" |> HTTPoison.get!

          t = Poison.Parser.parse!((request.body), keys: :atoms)

          case Map.get(t, :error) do
            nil ->
              reply send_message "It's *#{t.location.localtime}* in #{t.location.name}, #{t.location.region}, #{t.location.country}.", [parse_mode: "Markdown"]
            error ->
              reply send_message "#{error.message}"
          end
      end
    end

    command ["coin", "flip"] do
      reply send_message Enum.random(["Heads.", "Tails."])
    end

    command ["choose", "pick", "random"] do
      [_ | query] = String.split(message.text)
      choices = query |> Enum.join(" ") |> String.split(", ")
      reply send_message Enum.random(choices)
    end

    command ["predict", "ask"] do
      predictions = [
        "It is certain.",
        "It is decidedly so.",
        "Without a doubt.",
        "Yes, definitely.",
        "You may rely on it.",
        "As I see it, yes.",
        "Most likely.",
        "Outlook good.",
        "Yes.",
        "Signs point to yes.",
        "Reply hazy, try again.",
        "Ask again later.",
        "Better not tell you now.",
        "Cannot predict now.",
        "Concentrate and ask again.",
        "Don't count on it.",
        "My reply is no.",
        "My sources say no.",
        "Outlook not so good.",
        "Very doubtful."
      ]

      cond do
        length(message.text |> String.split) == 1 ->
          reply send_message "What is the question, kuma?"
        length(message.text |> String.split) > 1 ->
          reply send_message Enum.random(predictions)
      end
    end

    command "message" do
      request = "http://souls.riichi.me/api" |> HTTPoison.get!
      response = Poison.Parser.parse!((request.body), keys: :atoms)
      m = response.message

      reply send_message m
    end

    command "smug" do
      url = "https://api.imgur.com/3/album/zSNC1"
      auth = %{"Authorization" => "Client-ID #{Application.get_env(:kuma_bot, :imgur_client_id)}"}

      request = HTTPoison.get!(url, auth)
      response = Poison.Parser.parse!((request.body), keys: :atoms)

      try do
        reply send_chat_action "upload_photo"

        result = response.data.images |> Enum.shuffle |> Enum.find(fn post -> is_image?(post.link) == true end)
        file = download result.link

        reply send_photo file
        File.rm file
      rescue
        error ->
          reply send_message "fsdafsd"
          Logger.warn error
      end
    end

    command ["dan", "danbooru"] do
      try do
        [_ | search_term] = String.split(message.text)
        [tag1 | tag2] = search_term

        dan = cond do
          length(tag2) >= 1 -> danbooru(tag1, List.first(tag2))
          true -> danbooru(tag1, "")
        end

        case dan do
          {artist, post_id, file} ->
            caption = "Artist: #{artist}\n\nvia https://danbooru.donmai.us/posts/#{post_id}"

            reply send_chat_action "upload_photo"

            reply send_photo file, [caption: caption]
            File.rm file
          message -> reply send_message message
        end
      rescue
        _ ->
          {artist, post_id, file} = danbooru("order:rank", "")

          reply send_chat_action "upload_photo"

          caption = "Artist: #{artist}\n\nvia https://danbooru.donmai.us/posts/#{post_id}"

          reply send_photo file, [caption: caption]
          File.rm file
      end
    end

    command ["safe", "sfw"] do
      try do
        [_ | tag] = message.text |> String.split
        dan = danbooru(tag |> List.first, "rating:s")

        case dan do
          {artist, post_id, file} ->
            caption = "Artist: #{artist}\n\nvia https://danbooru.donmai.us/posts/#{post_id}"

            reply send_chat_action "upload_photo"

            reply send_photo file, [caption: caption]
            File.rm file
          message -> reply send_message message
        end
      rescue
        _ ->
          {artist, post_id, file} = danbooru("order:rank", "rating:s")

          reply send_chat_action "upload_photo"

          caption = "Artist: #{artist}\n\nvia https://danbooru.donmai.us/posts/#{post_id}"

          reply send_photo file, [caption: caption]
          File.rm file
      end
    end

    command ["lewd", "nsfw"] do
      try do
        [_ | tag] = message.text |> String.split
        dan = danbooru(tag |> List.first, Enum.random(["rating:q", "rating:e"]))

        case dan do
          {artist, post_id, file} ->
            caption = "Artist: #{artist}\n\nvia https://danbooru.donmai.us/posts/#{post_id}"

            reply send_chat_action "upload_photo"

            reply send_photo file, [caption: caption]
            File.rm file
          message -> reply send_message message
        end
      rescue
        _ ->
          {artist, post_id, file} = danbooru("order:rank", Enum.random(["rating:q", "rating:e"]))

          reply send_chat_action "upload_photo"

          caption = "Artist: #{artist}\n\nvia https://danbooru.donmai.us/posts/#{post_id}"

          reply send_photo file, [caption: caption]
          File.rm file
      end
    end

    command "tts" do
      try do
        [_ | message] = String.split(message.text)
        [first_word | rest] = message
        voice_input = first_word |> String.split(":")

        {voice, input} =
          cond do
            length(voice_input) == 2 ->
              [_ | voice] = voice_input
              {hd(voice), rest}
            true -> {"Will", message}
          end

        text = input |> Enum.join(" ")

        reply send_chat_action "record_audio"

        page = HTTPoison.get! "http://www.acapela-group.com/voices/demo/"
        {"Set-Cookie", session} = page.headers |> Enum.find(fn(x) -> x |> Tuple.to_list |> Enum.member?("Set-Cookie") end)

        url = "http://www.acapela-group.com/demo-tts/DemoHTML5Form_V2.php?langdemo"
        body = [MyLanguages: "sonid10", MySelectedVoice: voice, MyTextForTTS: text, t: "1", SendToVaaS: "", agreeterms: "on"]
        head = %{"User-Agent" => "Mozilla/5.0 (Windows; U; Windows NT 6.0; en-US) AppleWebKit/525.13 (KHTML, like Gecko) Chrome/0.2.149.29 Safari/525.13", "Content-type" => "application/x-www-form-urlencoded", "Cookie" => session}

        request = HTTPoison.post!(url, {:form, body}, head)
        %{"mp3" => file_url} = Regex.named_captures(~r/(?<mp3>((http:\/\/)?(www)?[-a-zA-Z0-9@:%_\+.~#?\/=]+\.mp3))/, request.body)

        file = download(file_url)

        reply send_voice file
        File.rm file
      rescue
        _ -> reply send_message "What?"
      end
    end

    command ["nhen", "nhentai", "doujin"] do
      [_ | tags] = message.text |> String.split

      case tags do
        [] -> reply send_message "You must search with at least one tag."
        tags ->
          tags = for tag <- tags do
            tag |> URI.encode_www_form
          end |> Enum.join("+")

          reply send_chat_action "upload_photo"

          request = "https://nhentai.net/api/galleries/search?query=#{tags}&sort=popular" |> HTTPoison.get!
          response = Poison.Parser.parse!((request.body), keys: :atoms)

          try do
            result = response.result |> Enum.shuffle |> Enum.find(fn doujin -> is_dupe?("nhentai", doujin.id) == false end)

            filetype = case List.first(result.images.pages).t do
              "j" -> "jpg"
              "g" -> "gif"
              "p" -> "png"
            end

            artists_tag = result.tags |> Enum.filter(fn(t) -> t.type == "artist" end)
            artists = for tag <- artists_tag, do: tag.name

            artist = case artists do
              [] -> ""
              artists -> "by #{artists |> Enum.sort |> Enum.join(", ")}\n"
            end

            cover = "https://i.nhentai.net/galleries/#{result.media_id}/1.#{filetype}"
            file = download cover

            caption = """
            #{result.title.pretty}
            #{artist}
            https://nhentai.net/g/#{result.id}
            """

            reply send_photo file, [caption: caption]
            File.rm file
        rescue
          KeyError -> reply send_message "Nothing found!"
        end
      end
    end

    command "me" do
      [_ | text] = String.split(message.text)

      case message do
        %{from: %{first_name: name}} ->
          reply send_message "#{name} #{text |> Enum.join(" ")}"
        %{from: %{username: name}} ->
          reply send_message "@#{name} #{text |> Enum.join(" ")}"
      end
    end

    command "projection", do: reply send_message "Psychological projection is a theory in psychology in which humans defend themselves against their own unpleasant impulses by denying their existence while attributing them to others. For example, a person who is rude may constantly accuse other people of being rude. It can take the form of blame shifting."

    command "convert" do
      try do
        [_ | [amount | currency]] = message.text |> String.split
        app_id = Application.get_env(:kuma_bot, :oxr_api)

        reply send_chat_action "typing"

        request = "https://openexchangerates.org/api/latest.json?app_id=#{app_id}" |> HTTPoison.get!
        response = Poison.Parser.parse!((request.body), keys: :atoms)
        rates = response.rates

        {amount, currency_from} = case amount |> Float.parse do
          :error -> {1.0, currency |> List.first |> String.upcase}
          parsed -> parsed
        end

        amount = amount |> Float.round(2)

        currency_from = case currency_from do
          "" -> currency |> List.first |> String.upcase
          currency_from -> currency_from |> String.upcase
        end

        currency_to = currency |> List.last |> String.upcase

        from_rate = rates |> Map.get(currency_from |> String.to_atom)
        to_rate = rates |> Map.get(currency_to |> String.to_atom)

        cond do
          from_rate == nil && to_rate == nil ->
            reply send_message "Neither #{currency_from} or #{currency_to} are valid currencies."
          from_rate == nil ->
            reply send_message "#{currency_from} is not a valid currency."
          to_rate == nil ->
            reply send_message "#{currency_to} is not a valid currency."
          true ->
            exchange_rate = to_rate / from_rate
            converted_amount = amount * exchange_rate

            reply send_message "#{amount |> Float.to_string(decimals: 2)} #{currency_from} is #{converted_amount |> Float.to_string(decimals: 2)} #{currency_to}.\n\n1 #{currency_from} = #{exchange_rate |> Float.round(5)} #{currency_to}"
        end
      rescue
        MatchError -> reply send_message "That didn't work. Be sure to use the format `/convert <amount> <from currency> <to currency>`.", [parse_mode: "Markdown"]
        e in ArgumentError -> reply send_message e.message
      end
    end

    match ["hello", "hi", "hey", "sup"] do
      replies = ["sup loser", "yo", "ay", "go away", "hi", "wassup"]
      if one_to(25) do
        reply send_message Enum.random(replies)
      end
    end

    match ["ty kuma", "thanks kuma", "thank you kuma"] do
      replies = ["np", "don't mention it", "anytime", "sure thing", "ye whateva"]
      reply send_message Enum.random(replies)
    end

    match ["same", "Same", "SAME"] do
      if one_to(25) do
        reply send_message "same"
      end
    end
  end
end
