#!/usr/bin/env bash
set -euo pipefail

python3 - "$@" <<'PYTHON'
import configparser
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile

nvim, init, task, taskopen, taskopen_config, task_config = sys.argv[1:]

with tempfile.TemporaryDirectory(prefix="taskwiki-regressions-") as temporary:
    root = Path(temporary)
    home = root / "home with spaces"
    wiki = home / "vimwiki"
    config_home = home / ".config"
    data_home = home / ".local/share"
    taskrc = config_home / "task/taskrc"
    taskdata = data_home / "task"
    for directory in (home, config_home / "task"):
        directory.mkdir(parents=True, exist_ok=True)
    generated_taskrc = taskrc.with_name("home-manager-taskrc")
    generated_taskrc.write_text(
        Path(task_config).read_text().replace("/home/taskwiki-test", str(home))
    )
    taskrc.write_text(f"include {generated_taskrc}\n")

    env = dict(os.environ)
    for key in ("VIMINIT", "EXINIT", "TASKRC", "TASKDATA", "TASKOPENRC", "BROWSER"):
        env.pop(key, None)
    env.update(
        HOME=str(home),
        XDG_CONFIG_HOME=str(config_home),
        XDG_DATA_HOME=str(data_home),
        XDG_STATE_HOME=str(home / ".local/state"),
        XDG_CACHE_HOME=str(home / ".cache"),
        TASKRC=str(taskrc),
        TASKDATA=str(taskdata),
        TZ="UTC",
        LC_ALL="C",
    )

    def run(*args, input=""):
        result = subprocess.run(
            args, env=env, input=input, text=True, capture_output=True, timeout=90
        )
        if result.returncode:
            raise AssertionError(
                f"{args!r} exited {result.returncode}\n{result.stdout}\n{result.stderr}"
            )
        return result

    def tw(*args):
        return run(task, "rc.confirmation=no", "rc.color=off", *args).stdout

    def tasks():
        return json.loads(tw("export"))

    def by_description(description):
        matches = [record for record in tasks() if record["description"] == description]
        assert len(matches) == 1, (description, matches)
        return matches[0]

    def edit(lua):
        script = root / "editor-test.lua"
        script.write_text(
            """
local ok, err = xpcall(function()
  assert(vim.g.taskwiki_taskrc_location == "/home/taskwiki-test/.config/task/taskrc")
  assert(vim.g.taskwiki_data_location == "/home/taskwiki-test/.local/share/task")
  assert(vim.g.vimwiki_global_ext == 0)
  assert(vim.g.vimwiki_markdown_link_ext == 1)
  assert(vim.fn.maparg(",ww", "n"):find("VimwikiIndex", 1, true))
  -- Relocate the generated fixture's absolute paths before opening any buffer.
  vim.g.taskwiki_taskrc_location = vim.env.TASKRC
  vim.g.taskwiki_data_location = vim.env.TASKDATA
  assert(vim.fn.py3eval("__import__('tasklib').__name__") == "tasklib")
  assert(vim.fn.py3eval("__import__('pynvim').__name__") == "pynvim")
  assert(vim.fn.py3eval("__import__('packaging').__name__") == "packaging")
  local function open(path)
    vim.cmd("edit " .. vim.fn.fnameescape(path))
  end
  local function find(text)
    for i, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
      if line:find(text, 1, true) then
        vim.api.nvim_win_set_cursor(0, {i, 0})
        -- Ex ranges expand closed folds; select a visible task, as a user would.
        vim.cmd("normal! zv")
        assert(vim.fn.foldclosed(i) == -1)
        return i
      end
    end
    error("Missing line: " .. text)
  end
"""
            + lua
            + """
end, debug.traceback)
if not ok then
  io.stderr:write(err .. "\\n")
  vim.cmd("cquit 1")
else
  vim.cmd("qa!")
end
"""
        )
        env["TASKWIKI_TEST_SCRIPT"] = str(script)
        return run(
            nvim, "--headless", "-u", init, "-i", "NONE",
            "-c", "lua dofile(vim.env.TASKWIKI_TEST_SCRIPT)",
        )

    assert not wiki.exists(), "Configuration must not prepopulate a wiki"
    outside = home / "ordinary.md"
    outside.write_text("* [ ] Not a Taskwarrior task\n")
    edit("""
  open(vim.env.HOME .. "/ordinary.md")
  assert(vim.bo.filetype == "markdown", vim.bo.filetype)
  assert(vim.fn.exists(":TaskWikiBufferSave") == 0)
  vim.cmd("write")
""")
    assert tasks() == [], "Ordinary Markdown unexpectedly created a task"
    assert not wiki.exists(), "Opening ordinary Markdown created a wiki"

    wiki.mkdir()
    page = wiki / "index.md"
    page.write_text("# Tasks\n")
    creation = edit("""
  open(vim.env.HOME .. "/vimwiki/index.md")
  assert(vim.bo.filetype == "vimwiki", vim.bo.filetype)
  assert(vim.fn.exists(":TaskWikiBufferSave") == 2)
  assert(vim.fn.maparg(",td", "n"):find("TaskWikiDone", 1, true))
  assert(vim.fn.maparg(",tm", "n"):find("TaskWikiMod", 1, true))
  vim.api.nvim_buf_set_lines(0, 0, -1, false, {
    "# Tasks",
    "",
    "## Home tasks | project:Home +PENDING | project:Home",
    "* [ ] Write documentation",
    "* [ ] Plan deployment",
    "  * [ ] Read release notes",
    "- [ ] An ordinary checklist item",
  })
  vim.cmd("write")
  vim.cmd("write")
""")
    initial = tasks()
    assert len(initial) == 3, (initial, creation.stdout, creation.stderr, page.read_text())
    assert all(record["project"] == "Home" for record in initial), initial
    parent = by_description("Plan deployment")
    child = by_description("Read release notes")
    assert child["uuid"] in parent["depends"], parent
    for record in initial:
        assert record["uuid"][:8] in page.read_text(), record
    uuids = {record["uuid"] for record in initial}

    tw("add", "From terminal", "project:Home")
    tw("add", "Hidden task", "project:Elsewhere")
    modification = edit("""
  open(vim.env.HOME .. "/vimwiki/index.md")
  find("From terminal")
  for _, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
    assert(not line:find("Hidden task", 1, true))
  end
  find("Write documentation")
  vim.cmd("TaskWikiMod due:tomorrow")
  vim.cmd("TaskWikiStart")
  vim.cmd("TaskWikiStop")
  vim.cmd("TaskWikiAnnotate https://example.invalid/guide?one=1&two=2")
  vim.cmd("TaskWikiLink")
  local row = find("Write documentation")
  local line = vim.api.nvim_get_current_line():gsub("Write documentation", "Document workflow")
  vim.api.nvim_buf_set_lines(0, row - 1, row, false, {line})
  vim.cmd("write")
  find("From terminal")
  vim.cmd("TaskWikiDone")
  vim.cmd("write")
  vim.cmd("TaskWikiBufferLoad")
  for _, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
    assert(not line:find("From terminal", 1, true))
  end
""")
    records = tasks()
    assert uuids.issubset({record["uuid"] for record in records})
    assert len(records) == 5, records
    edited = by_description("Document workflow")
    assert edited["status"] == "pending", (
        edited, modification.stdout, modification.stderr, page.read_text()
    )
    assert "due" in edited and "start" not in edited, edited
    assert by_description("From terminal")["status"] == "completed"
    for description in ("Plan deployment", "Read release notes"):
        untouched = by_description(description)
        assert untouched["status"] == "pending", untouched
        assert "annotations" not in untouched and "due" not in untouched, untouched
    annotations = [annotation["description"] for annotation in edited["annotations"]]
    assert f"wiki: {page}" in annotations, annotations
    assert "https://example.invalid/guide?one=1&two=2" in annotations, annotations

    # Mock only external programs, retaining the generated taskopen action logic.
    parser = configparser.ConfigParser(interpolation=None)
    parser.optionxform = str
    parser.read(taskopen_config)
    settings = {
        section: {key: json.loads(value) for key, value in parser[section].items()}
        for section in parser.sections()
    }
    assert settings["General"]["no_annotation_hook"] == ""
    assert settings["General"]["taskbin"] == task
    assert settings["General"]["EDITOR"] == nvim
    assert not (wiki / "tasknotes").exists()

    log = root / "opened.jsonl"
    recorder = root / "record-open"
    recorder.write_text(
        f"#!{sys.executable}\n"
        "import json, os, sys\n"
        "with open(os.environ['TASKWIKI_OPEN_LOG'], 'a') as output:\n"
        "    output.write(json.dumps(sys.argv[1:]) + '\\n')\n"
        "sys.exit(int(os.environ.get('TASKWIKI_OPEN_EXIT', '0')))\n"
    )
    recorder.chmod(0o755)
    settings["General"]["EDITOR"] = str(recorder)
    env["BROWSER"] = str(recorder)
    env["TASKWIKI_OPEN_LOG"] = str(log)
    file_command = settings["Actions"]["files.command"]
    opener = file_command.split("*) exec ", 1)[1].split(' "$FILE"', 1)[0]
    for key in ("files.command", "url.command"):
        settings["Actions"][key] = settings["Actions"][key].replace(
            opener, shlex.quote(str(recorder))
        )
    configured_taskopen = config_home / "taskopen/taskopenrc"
    configured_taskopen.parent.mkdir()
    configured_taskopen.write_text("".join(
        f"[{section}]\n"
        + "".join(f"{key} = {json.dumps(value)}\n" for key, value in values.items())
        for section, values in settings.items()
    ))
    env["TASKOPENRC"] = str(configured_taskopen)

    def opened():
        return [json.loads(line) for line in log.read_text().splitlines()]

    file_open = run(taskopen, "--debug", "--include=files", edited["uuid"])
    assert log.exists(), (
        file_open.stdout, file_open.stderr, run(taskopen, "diagnostics").stdout,
        tw("rc.verbose=blank,label,edit", "rc.json.array=on", "rc.gc=off",
           "", edited["uuid"], "+PENDING", "export"),
    )
    assert opened()[-1] == [str(page)], opened()
    run(taskopen, "--include=url", edited["uuid"])
    assert opened()[-1] == ["https://example.invalid/guide?one=1&two=2"], opened()
    env.pop("BROWSER")
    run(taskopen, "--include=url", edited["uuid"])
    assert opened()[-1] == ["https://example.invalid/guide?one=1&two=2"], opened()

    tw(edited["uuid"], "annotate", "--", "Notes")
    run(taskopen, "--include=notes", edited["uuid"])
    note = wiki / "tasknotes" / f"{edited['uuid']}.md"
    assert note.parent.is_dir()
    assert opened()[-1] == [str(note)], opened()
    before = len(opened())
    run(taskopen, edited["uuid"], input="1\n")
    assert len(opened()) == before + 1
    assert opened()[-1] in [
        [str(page)], [str(note)], ["https://example.invalid/guide?one=1&two=2"]
    ]

    attachment = home / "attachment $(not-a-command); with spaces.txt"
    attachment.write_text("An ordinary attachment.\n")
    hidden = by_description("Hidden task")
    before = len(opened())
    run(taskopen, hidden["uuid"])
    assert len(opened()) == before
    assert "annotations" not in by_description("Hidden task")
    tw(hidden["uuid"], "annotate", "--", str(attachment))
    run(taskopen, hidden["uuid"])
    assert opened()[-1] == [str(attachment)], opened()

    binary = home / "binary attachment.bin"
    binary.write_bytes(b"\x00fixture")
    tw("add", "Binary attachment")
    binary_task = by_description("Binary attachment")
    tw(binary_task["uuid"], "annotate", "--", str(binary))
    run(taskopen, binary_task["uuid"])
    assert opened()[-1] == [str(binary)], opened()

    env["TASKWIKI_OPEN_EXIT"] = "7"
    failure = run(taskopen, hidden["uuid"])
    assert "failed with exit code: 7" in failure.stdout + failure.stderr
    assert not (home / "tasknotes").exists(), "Upstream default notes directory leaked"
    assert not (home / "Notes").exists(), "Upstream helper unexpectedly created notes"

print("Taskwiki and taskopen regressions passed.")
PYTHON
