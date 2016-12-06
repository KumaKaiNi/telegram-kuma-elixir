defmodule KumaBot.Util do
  require Logger

  def one_to(n), do: Enum.random(1..n) <= 1
  def percent(n), do: Enum.random(1..100) <= n

  def is_image?(url) do
    Logger.info "Checking if #{url} is an image..."
    image_types = [".jpg", ".jpeg", ".gif", ".png"]
    Enum.member?(image_types, Path.extname(url))
  end

  def download(url) do
    filename = url |> String.split("/") |> List.last
    filepath = "_data/temp/#{filename}"

    Logger.log :info, "Downloading #{filename}..."
    image = url |> HTTPoison.get!
    File.write filepath, image.body
    Logger.log :info, "Download finished."

    filepath
  end

  def download_dep(url) do
    filename = url |> String.split("/") |> List.last
    filepath = "_data/deps/#{filename}"

    unless File.exists?(filepath) do
      Logger.log :info, "Downloading #{filename}..."
      image = url |> HTTPoison.get!
      File.write filepath, image.body
      Logger.log :info, "Download finished."
    end

    filepath
  end

  def is_dupe?(source, filename) do
    Logger.info "Checking if #{filename} was last posted..."
    file = query_data("dupes", source)

    cond do
      file == nil ->
        store_data("dupes", source, filename)
        false
      file != filename ->
        store_data("dupes", source, filename)
        false
      file == filename -> true
      true -> nil
    end
  end

  def danbooru(tag1, tag2) do
    dan = "danbooru.donmai.us"

    tag1 = tag1 |> URI.encode_www_form
    tag2 = tag2 |> URI.encode_www_form

    request =
      "http://#{dan}/posts.json?limit=50&page=1&tags=#{tag1}+#{tag2}"
      |> HTTPoison.get!

    try do
      results = Poison.Parser.parse!((request.body), keys: :atoms)
      result = results |> Enum.shuffle |> Enum.find(fn post -> is_image?(post.file_url) == true && is_dupe?("dan", post.file_url) == false end)

      artist = result.tag_string_artist |> String.split("_") |> Enum.join(" ")
      post_id = Integer.to_string(result.id)
      file = download "http://#{dan}#{result.file_url}"

      {artist, post_id, file}
    rescue
      Enum.EmptyError -> "Nothing found!"
      UndefinedFunctionError -> "Nothing found!"
      error ->
        Logger.warn error
        "fsdafsd"
    end
  end

  def store_data(table, key, value) do
    file = '_data/db/#{table}.dets'
    {:ok, _} = :dets.open_file(table, [file: file, type: :set])

    :dets.insert(table, {key, value})
    :dets.close(table)
  end

  def query_data(table, key) do
    file = '_data/db/#{table}.dets'
    {:ok, _} = :dets.open_file(table, [file: file, type: :set])
    result = :dets.lookup(table, key)

    response =
      case result do
        [{_, value}] -> value
        [] -> nil
      end

    :dets.close(table)
    response
  end

  def delete_data(table, key) do
    file = '_data/db/#{table}.dets'
    {:ok, _} = :dets.open_file(table, [file: file, type: :set])
    response = :dets.delete(table, key)

    :dets.close(table)
    response
  end

  def celsius(fahrenheit), do: (fahrenheit - 32) * (5/9) |> round
  def fahrenheit(celsius), do: (celsius * (5/9)) + 32 |> round

  def kuma_replies do
    [
      "http://vignette2.wikia.nocookie.net/kancolle/images/3/38/Kuma-Introduction.ogg",
      "http://vignette4.wikia.nocookie.net/kancolle/images/3/31/Kuma-Library.ogg",
      "http://vignette2.wikia.nocookie.net/kancolle/images/c/c3/Kuma-Secretary_2.ogg",
      "http://vignette2.wikia.nocookie.net/kancolle/images/f/f0/Kuma-Secretary_3.ogg",
      "http://vignette1.wikia.nocookie.net/kancolle/images/0/04/KumaKai-Idle.ogg",
      "http://vignette1.wikia.nocookie.net/kancolle/images/c/c0/Kuma-Looking_At_Scores.ogg",
      "http://vignette4.wikia.nocookie.net/kancolle/images/9/93/Kuma-Joining_A_Fleet.ogg",
      "http://vignette3.wikia.nocookie.net/kancolle/images/7/77/Kuma-Equipment_1.ogg",
      "http://vignette4.wikia.nocookie.net/kancolle/images/d/d6/Kuma-Equipment_2.ogg",
      "http://vignette2.wikia.nocookie.net/kancolle/images/c/ca/Kuma-Equipment_3.ogg",
      "http://vignette1.wikia.nocookie.net/kancolle/images/c/c6/Kuma_Supply.ogg",
      "http://vignette2.wikia.nocookie.net/kancolle/images/2/21/KumaKai-Supply.ogg",
      "http://vignette3.wikia.nocookie.net/kancolle/images/0/0b/Kuma-Docking_Minor.ogg",
      "http://vignette1.wikia.nocookie.net/kancolle/images/f/f2/Kuma-Docking_Major.ogg",
      "http://vignette2.wikia.nocookie.net/kancolle/images/a/ae/Kuma-Docking_Complete.ogg",
      "http://vignette1.wikia.nocookie.net/kancolle/images/5/57/Kuma-Construction.ogg",
      "http://vignette3.wikia.nocookie.net/kancolle/images/7/7d/Kuma-Returning_From_Sortie.ogg",
      "http://vignette4.wikia.nocookie.net/kancolle/images/c/c5/Kuma-Starting_A_Sortie.ogg",
      "http://vignette2.wikia.nocookie.net/kancolle/images/5/51/Kuma-Battle_Start.ogg",
      "http://vignette3.wikia.nocookie.net/kancolle/images/5/5c/Kuma-Attack.ogg",
      "http://vignette3.wikia.nocookie.net/kancolle/images/2/24/Kuma-Night_Battle.ogg",
      "http://vignette1.wikia.nocookie.net/kancolle/images/8/83/Kuma-Night_Attack.ogg",
      "http://vignette4.wikia.nocookie.net/kancolle/images/d/d8/Kuma-MVP.ogg",
      "http://vignette4.wikia.nocookie.net/kancolle/images/b/ba/Kuma-Minor_Damage_1.ogg",
      "http://vignette1.wikia.nocookie.net/kancolle/images/6/66/Kuma-Minor_Damage_2.ogg",
      "http://vignette1.wikia.nocookie.net/kancolle/images/d/d1/Kuma-Major_Damage.ogg",
      "http://vignette1.wikia.nocookie.net/kancolle/images/d/d8/Kuma_Rainy_Season_2015.ogg",
      "http://vignette2.wikia.nocookie.net/kancolle/images/c/cc/Kuma_Mid-Summer_2015_Secretary_1.ogg",
      "http://vignette2.wikia.nocookie.net/kancolle/images/4/47/Kuma_Autumn_2015.ogg",
      "http://vignette2.wikia.nocookie.net/kancolle/images/3/35/Kuma_End_of_Year_2015.ogg",
      "http://vignette2.wikia.nocookie.net/kancolle/images/2/22/Kuma_New_Year_2016.ogg"
    ]
  end
end
