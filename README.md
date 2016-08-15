# Statix

WIP WIP WIP

Statix is K.I.S.S. inspired static website generator. It merges Mustache templates and JSON data files together. It supports a simple I18N.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add `statix` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:statix, "~> 0.1.0"}]
    end
    ```

  2. Ensure `statix` is started before your application:

    ```elixir
    def application do
      [applications: [:statix]]
    end
    ```

## Usage

Statix expects the following simple directory structure:

    data/
      files.json
      as_you_want.json
    locales/
      en.json
      de.json
      whatever.json
    templates/
      index.mustache
      some_sub_dir/
        more.mustache

You can generate a new structure using the built-in mix task, where the project name is the name of the resulting directory.

    $ mix statix.new project_name

Use the built-in mix task to compile the input directory:

    $ mix statix.compile source_directory output_directory
