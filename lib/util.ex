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
end
