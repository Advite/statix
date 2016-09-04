defmodule Statix do
	require Logger

	defstruct available_locales: [],
						default_locale: 	 nil,
						locales_data:      nil,
						locales_html:      nil,
						partials:          nil,
						source_path:       nil,
						destination_path:  nil,
						data:              nil

	@max_locales 99
	@templates_dir "templates"
	@locales_dir "locales"
	@default_output_dir "static"
	@data_dir "data"
	@assets_dir "assets"
	@templates_file_extension "mustache.html"
	@data_file_extension "json"
	@html_file_extension "html"
	@extra_data_separator "+++"

	def init(path, options \\ []) do
		locales_data = load_locales_data(path)
		locales_html = load_locales_html(path)
		[first_locale|_]=locales = available_locales(locales_data)
		path = ensure_path!(path)
		%Statix{
			available_locales: locales,
			source_path: 			 path,
			destination_path:  Keyword.get(options, :destination_path, @default_output_dir),
			locales_data: 		 locales_data,
			locales_html:      locales_html,
			data:              load_data(path),
			partials:          load_partials(path),
			default_locale:    Keyword.get(options, :default_locale, first_locale) }
			|> clean!
	end

	def compile!(path \\ ".", options \\ []), do:
		init(path, options) |> compile_templates! |> copy_assets!

	defp available_locales(data), do:
		Map.keys(data) |> Enum.sort

	def clean!(builder) do
		File.ls!(builder.destination_path)
			|> Enum.each(fn f -> Path.join(builder.destination_path, f) |> File.rm_rf! end)
		builder
	end

	def ensure_path!(path) do
		File.mkdir_p!(path)
		path
	end

	def compile_template!(builder, path), do:
		compile_template!(builder, path, builder.available_locales)
	def compile_template!(_builder, _path, []), do: :ok

	def compile_template!(builder, path, [locale|locales]) do
		compile_template!(builder, path, locale)
		compile_template!(builder, path, locales)
	end

	def compile_template!(builder, path, locale) when is_binary(locale) do
		render_data = Map.merge(builder.data, %{
			"i18n" => builder.locales_data[locale],
			"locale" => locale })

		# Render the html templates with the data already present, but
		# will ignore other html data. This should be cached per locale to
		# speed up. TODO
		render_data = Map.merge(render_data, %{
			"html" => Enum.map(builder.locales_html[locale], fn (k) ->
				{name, %{"body" => body}=v} = k
				rendered_body = Mustachex.render(body, render_data, partials: builder.partials)
				v = Map.put(v, "body", rendered_body)
				{name, v}
				end) |> Enum.into(%{})
		})

		template = File.read!(path)
  	{render_data, template} = case String.split(template, @extra_data_separator, trim: true) do
			[data, template] ->
				new_render_data = Map.merge(render_data, %{ "extra" => Poison.Parser.parse!(data) })
				{new_render_data, String.trim(template)}
			_ -> {render_data, template}
  	end

		output_content = Mustachex.render(template, render_data, partials: builder.partials)
		templates_prefix_path = templates_path(builder.source_path)
		unless String.starts_with?(path, templates_prefix_path), do: throw("Bad path #{path}")

		output_file_path = Path.relative_to(path, templates_prefix_path)
		destination_path = Path.join(Path.join(builder.destination_path, to_string(locale)), output_file_path)
		template_filename = Path.basename(output_file_path)
		[template_base_filename] = String.split(template_filename, ".#{@templates_file_extension}", trim: true)

		# Does the path have locale in it? If it does, than do it just if
		# the given locale matches it.
		parts = String.split(template_base_filename, ".")
		possible_locale = List.last(parts) |> String.downcase
		is_possible_locale = Enum.member?(builder.available_locales, possible_locale)
		is_single_locale_content = is_possible_locale and (possible_locale == locale)
		if is_single_locale_content or not is_possible_locale do
			template_html_filename = if is_single_locale_content, do:
				"#{Enum.slice(parts, 0, Enum.count(parts) - 1) }.html", else: "#{template_base_filename}.html"
			output_filename_path = Path.join(Path.dirname(destination_path), template_html_filename)
			gz_output_filename_path = Path.join(Path.dirname(destination_path), template_html_filename) <> ".gzip"
			ensure_path!(Path.dirname(output_filename_path))
			Logger.debug "#{path} [#{locale}] => #{output_filename_path}"
			File.write!(output_filename_path, output_content)
			Logger.debug "#{path} [#{locale}] => #{gz_output_filename_path}"
			File.write!(gz_output_filename_path, output_content, [:compressed])

			{:ok, output_filename_path, output_content}
		else
			Logger.debug "Skipping #{path} [#{locale}]"
		end
	end

	def compile_templates!(builder) do
		{:ok, walker} = DirWalker.start_link(templates_path(builder.source_path), include_dir_names: false, matching: ~r/^([^_].*\.#{@templates_file_extension})$/)
		walk_templates(builder, walker)
		builder
	end

	defp walk_templates(builder, walker) do
		case DirWalker.next(walker) do
			nil -> :ok
			[path] ->
				compile_template!(builder, path)
				walk_templates(builder, walker)
		end
	end

	defp templates_path(base_path), do:
		Path.join(base_path, @templates_dir)

	defp data_path(base_path), do:
		Path.join(base_path, @data_dir)

	defp locales_path(base_path), do:
		Path.join(base_path, @locales_dir)

	defp assets_path(base_path), do:
		Path.join(base_path, @assets_dir)

	defp load_data(base_path) do
		{:ok, walker} = DirWalker.start_link(data_path(base_path), include_dir_names: false, matching: ~r/^(.*\.#{@data_file_extension})$/)
		walk_data_files(data_path(base_path), walker, %{})
	end

	defp load_locales_data(base_path) do
		{:ok, walker} = DirWalker.start_link(locales_path(base_path), include_dir_names: false, matching: ~r/^(.*\.#{@data_file_extension})$/)
		walk_data_files(locales_path(base_path), walker, %{})
	end

	defp walk_data_files(from_data_path, walker, data) do
		case DirWalker.next(walker) do
			nil -> data
			[]  ->
				Logger.debug "No data files found in #{from_data_path}"
				%{}
		  [path] ->
		  	[data_file_base_name] = Path.basename(path) |> String.split(".#{@data_file_extension}", trim: true)
		  	file_data = load_data_file(path)
		  	data_path_scope = Path.relative_to(path, from_data_path) |> Path.dirname
		  	data_path_scope = if String.starts_with?(data_path_scope, "."), do:
		  		String.slice(data_path_scope, 1..-1), else: data_path_scope
		  	data_scope = (Path.split(data_path_scope) ++ [data_file_base_name])
		  		|> Enum.map(&Inflex.camelize(&1, :lower))
		  		|> Enum.join(".")
		  	new_data = Map.merge(data, %{ data_scope => file_data })
		  	walk_data_files(from_data_path, walker, new_data)
		end
	end

	defp load_data_file(path), do:
		File.read!(path) |> Poison.Parser.parse!

	defp load_locales_html(base_path) do
		{:ok, walker} = DirWalker.start_link(locales_path(base_path), include_dir_names: false, matching: ~r/^(.*\.#{@html_file_extension})$/)
		walk_html_files(locales_path(base_path), walker, %{})
	end

	defp walk_html_files(from_data_path, walker, data) do
		case DirWalker.next(walker) do
			nil -> data
			[]  ->
				Logger.debug "No html files found in #{from_data_path}"
				%{}
		  [path] ->
		  	[data_file_base_name] = Path.basename(path) |> String.split(".#{@html_file_extension}", trim: true)
		  	base_name_local_parts = String.split(data_file_base_name, ".", trim: true)
		  	base_name_locale = List.last(base_name_local_parts)
		  	base_name = Enum.slice(base_name_local_parts, 0, Enum.count(base_name_local_parts)-1)
		  		|> Enum.join(".")
		  		|> Inflex.camelize(:lower)
		  	file_data = File.read!(path) |> String.trim
		  	{html_data, html_text} = case String.split(file_data, @extra_data_separator, trim: true) do
	  			[data, html] -> {Poison.Parser.parse!(data), String.trim(html)}
	  			_ -> {%{}, file_data}
		  	end
		  	html_data = Map.merge(html_data, %{ "body" => html_text })
		  	new_data = Map.merge(data, %{ base_name_locale => %{ base_name => html_data }}, fn _k, v1, v2 -> Map.merge(v1, v2) end)
		  	walk_html_files(from_data_path, walker, new_data)
		end
	end


	defp load_partials(base_path) do
		{:ok, walker} = DirWalker.start_link(templates_path(base_path), matching: ~r/^\_(.*\.#{@templates_file_extension})$/)
		walk_partials_files(walker)
	end

	defp walk_partials_files(walker, data \\ %{}) do
		case DirWalker.next(walker) do
			nil -> data
			[] ->
				Logger.debug "No partials found"
				%{}
		  [path] ->
		  	[partial_name] = path
		  		|> Path.basename
		  		|> String.slice(1..-1)
		  		|> String.split(".#{@templates_file_extension}", trim: true)
		  	partial_name = Inflex.camelize(partial_name, :lower) |> String.to_atom
		  	partial_data = File.read!(path)
		  	new_data = Map.merge(data, %{ partial_name => partial_data })
		  	walk_partials_files(walker, new_data)
		end
	end

	defp copy_assets!(builder) do
		assets_dir = assets_path(builder.source_path)
		if File.exists?(assets_dir), do:
			{:ok, _} = File.cp_r(assets_dir, builder.destination_path)
		builder
	end

	def create!(name) do
		File.mkdir!(name)
		assets_path = Path.join(name, @assets_dir)
  	File.mkdir(assets_path)
  	File.write(Path.join(assets_path, "robots.txt"), "User-agent: *\nDisallow:\n")
  	data_path = Path.join(name, @data_dir)
  	File.mkdir(data_path)
  	File.write(Path.join(data_path, "hello.#{@data_file_extension}"), "{ \"name\": \"Statix\" }")
  	locales_path = Path.join(name, @locales_dir)
  	File.mkdir(locales_path)
  	File.write!(Path.join(locales_path, "en.json"), "{\"greeting\": \"Hello\"}")
  	templates_path = Path.join(name, @templates_dir)
  	File.mkdir(templates_path)
  	File.write!(Path.join(templates_path, "index.#{@templates_file_extension}"), "{{i18n.greeting}} {{hello.name}}!")
	end


end
