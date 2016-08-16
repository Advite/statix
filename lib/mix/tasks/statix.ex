defmodule Mix.Tasks.Statix.Compile do
  use Mix.Task

  @shortdoc "Compile a statix project"

  def run([src_path, dest_path]), do:
  	Statix.compile!(src_path, destination_path: dest_path)

  def run(_), do:
  	IO.puts("Usage:\n\t$ mix statix.compile source_directory destination_directory")
end

defmodule Mix.Tasks.Statix.New do
  use Mix.Task

  @shortdoc "Compile a statix project"
  def run([project_name]), do:
  	Statix.create!(project_name)

  def run(_), do:
  	IO.puts("Usage:\n\t$ mix statix.new project_name")
end
