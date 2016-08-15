defmodule Mix.Tasks.Statix.Compile do
  use Mix.Task

  @shortdoc "Compile a statix project"
  def run([src_path, dest_path]) do
  	Statix.compile!(src_path, output_path: dest_path)
  end
  def run(_), do:
  	IO.puts("Usage:\n\t$ mix statix.compile source_directory destination_directory")
end

defmodule Mix.Tasks.Statix.New do
  use Mix.Task

  @shortdoc "Compile a statix project"
  def run([project_name]) do
  	File.mkdir!(project_name)
  	File.mkdir(Path.join(project_name, "assets"))
  	File.mkdir(Path.join(project_name, "data"))
  	locales_path = Path.join(project_name, "locales")
  	File.mkdir(locales_path)
  	File.write!(Path.join(locales_path, "en.json"), "{\"greeting\": \"Hello Statix!\"}")
  	templates_path = Path.join(project_name, "templates")
  	File.mkdir(templates_path)
  	File.write!(Path.join(templates_path, "index.mustache"), "{{i18n.greeting}}")
  end
  def run(_), do:
  	IO.puts("Usage:\n\t$ mix statix.new project_name")
end
