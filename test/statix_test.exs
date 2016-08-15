defmodule StatixTest do
  use ExUnit.Case
  doctest Statix

  test "fetch available locales" do
  	builder = Statix.init("test/example_site", output_path: "test/static")
  	assert ["de", "en"] == builder.available_locales
  end

  test "clean build path" do
  	builder = Statix.init("test/example_site", output_path: "test/static")
  	File.mkdir_p!(builder.output_path)
  	assert File.exists?(builder.output_path)
  	Statix.clean!(builder)
  	assert !File.exists?(builder.output_path)
  end

  test "ensure path exists" do
  	builder = Statix.init("test/example_site", output_path: "test/static")
  	test_path = "test/static/random/path/to/somewhere"
  	^test_path = Statix.ensure_path!(test_path)
  	assert File.exists?(test_path)
  	Statix.clean!(builder)
  	assert !File.exists?(test_path)
  end

  test "compile template to output build" do
  	builder = Statix.init("test/example_site", output_path: "test/static")
  	:ok = Statix.compile_template!(builder, "test/example_site/templates/index.mustache")
  	assert File.exists?("test/static/de/index.html")
  	"Deutsch\nTest Product 1\n" = File.read!("test/static/de/index.html")
  	assert File.exists?("test/static/en/index.html")
  	"English\nTest Product 1\n" = File.read!("test/static/en/index.html")
  end

  test "compile directory templates to output build" do
  	builder = Statix.init("test/example_site", output_path: "test/static")
  	:ok = Statix.compile_templates!(builder)
  	assert File.exists?("test/static/de/index.html")
  	assert File.exists?("test/static/de/faq.html")
  	assert File.exists?("test/static/en/index.html")
  	assert File.exists?("test/static/en/faq.html")
  end

end
