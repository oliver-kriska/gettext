defmodule Mix.Tasks.Gettext.ExtractFromAttributes do
  use Mix.Task
  @recursive true

  @shortdoc "Extracts messages from compiled BEAM files without recompiling"

  @moduledoc """
  Extracts messages without force-recompiling the project (experimental).

  ```bash
  mix gettext.extract_from_attributes [OPTIONS]
  ```

  Unlike `mix gettext.extract`, which force-recompiles the whole project so
  that the Gettext macros run again, this task reads the messages back from
  the compiled BEAM files. It compiles the project normally (a no-op when it
  is already compiled) and then scans the persisted module attributes, so it
  avoids the cost of a force-recompile.

  For this to work, messages must have been persisted as module attributes
  during normal compilation. This happens automatically when the backend has
  automatic extraction enabled in the application environment, which you
  typically set in `config/dev.exs` so it stays off in `:prod`:

      # config/dev.exs
      config :gettext, MyApp.Gettext, automatic_extraction: true

  Since the attributes are only persisted when `automatic_extraction` is
  enabled (so not in `:prod`), release artifacts are unaffected.

  This task accepts the same `--merge` and `--check-up-to-date` options as
  `mix gettext.extract`, and forwards any other options to
  `Mix.Tasks.Gettext.Merge`:

  ```bash
  mix gettext.extract_from_attributes --merge --no-fuzzy
  mix gettext.extract_from_attributes --check-up-to-date
  ```

  """

  @switches [merge: :boolean, check_up_to_date: :boolean]

  @impl true
  def run(args) do
    Application.ensure_all_started(:gettext)
    _ = Mix.Project.get!()
    mix_config = Mix.Project.config()
    {opts, _} = OptionParser.parse!(args, switches: @switches)
    pot_files = extract(mix_config[:app], mix_config[:gettext] || [])
    Mix.Tasks.Gettext.Extract.process(pot_files, opts, args)
  end

  defp extract(app, gettext_config) do
    # The project is compiled (and its attributes persisted) by the normal
    # compilation; here we just make sure that has happened. This is a no-op
    # when the project is already compiled.
    Mix.Task.run("compile", [])

    {backends, messages} =
      Gettext.Extractor.fill_from_compiled_beams(Mix.Project.compile_path())

    if backends == 0 and messages == 0 do
      Mix.raise("""
      mix gettext.extract_from_attributes found no persisted Gettext messages \
      or backends in #{Path.relative_to_cwd(Mix.Project.compile_path())}.

      Messages are persisted to module attributes during normal compilation only \
      when the backend has automatic extraction enabled in the application \
      environment, for example in config/dev.exs:

          config :gettext, MyApp.Gettext, automatic_extraction: true

      If you just enabled this or updated Gettext, force a recompile so that \
      up-to-date modules get their attributes written:

          mix compile --force
      """)
    end

    Gettext.Extractor.pot_files(app, gettext_config)
  end
end
