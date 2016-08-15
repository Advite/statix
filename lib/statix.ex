defmodule Statix do
	require Logger

	defstruct available_locales: [],
						default_locale: nil,
						locales_data: %{},
						source_path: nil,
						output_path: nil,
						data: %{}

	@max_locales 99
	@templates_dir "templates"
	@locales_dir "locales"
	@default_output_dir "static"
	@data_dir "data"

	def init(path, options \\ []) do
		locales_data = load_locales_data(path)
		[first_locale|_]=locales = available_locales(locales_data)
		path = ensure_path!(path)
		%Statix{
			available_locales: locales,
			source_path: path,
			output_path: Keyword.get(options, :output_path, @default_output_dir),
			locales_data: locales_data,
			data: load_data(path),
			default_locale: Keyword.get(options, :default_locale, first_locale) }
	end

	def compile!(path \\ ".", options \\ []), do:
		init(path, options) |> compile_templates!

	defp available_locales(data), do:
		Map.keys(data) |> Enum.sort

	def clean!(builder) do
		File.rm_rf!(builder.output_path)
		false = File.exists?(builder.output_path)
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
		template = File.read!(path)
		output_content = Mustachex.render(template, Map.merge(%{ i18n: builder.locales_data[locale] }, builder.data))
		templates_prefix_path = templates_path(builder.source_path)
		unless String.starts_with?(path, templates_prefix_path), do: throw("Bad path #{path}")

		output_file_path = Path.relative_to(path, templates_prefix_path)
		output_path = Path.join(Path.join(builder.output_path, locale), output_file_path)
		template_filename = Path.basename(output_file_path)
		[template_base_filename] = String.split(template_filename, template_file_extension, trim: true)
		template_html_filename = "#{template_base_filename}.html"
		output_filename_path = Path.join(Path.dirname(output_path), template_html_filename)

		ensure_path!(Path.dirname(output_filename_path))
		Logger.info "#{path} [#{locale}] => #{output_filename_path}"
		File.write!(output_filename_path, output_content)
		{:ok, output_filename_path, output_content}
	end


	def compile_templates!(builder) do
		{:ok, walker} = DirWalker.start_link(templates_path(builder.source_path), include_stat: false, include_dir_names: false)
		walk_templates(builder, walker)
	end

	defp walk_templates(builder, walker) do
		case DirWalker.next(walker, 1) do
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

	defp template_file_extension do
		".mustache"
	end

	defp load_data(base_path) do
		{:ok, walker} = DirWalker.start_link(data_path(base_path), include_stat: false, include_dir_names: false, matches: ~r/^(.*\.json$)$/)
		walk_data_files(data_path(base_path), walker, %{})
	end

	defp load_locales_data(base_path) do
		{:ok, walker} = DirWalker.start_link(locales_path(base_path), include_stat: false, include_dir_names: false, matches: ~r/^(.*\.json$)$/)
		walk_data_files(locales_path(base_path), walker, %{})
	end

	defp walk_data_files(from_data_path, walker, data) do
		case DirWalker.next(walker, 1) do
			nil -> data
			[]  ->
				Logger.debug "No data files found in #{from_data_path}"
				%{}
		  [path] ->
		  	[data_file_base_name] = Path.basename(path) |> String.split(".json", trim: true)
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

end
