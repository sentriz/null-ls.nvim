local diagnostics = require("null-ls.builtins").diagnostics

describe("diagnostics", function()
    describe("chktex", function()
        local linter = diagnostics.chktex
        local parser = linter._opts.on_output
        local file = {
            [[\documentclass{article}]],
            [[\begin{document}]],
            [[Lorem ipsum dolor \sit amet]],
            [[\end{document}]],
        }

        it("should create a diagnostic", function()
            local output = [[3:23:1:Warning:1:Command terminated with space.]]
            local diagnostic = parser(output, { content = file })
            assert.are.same({
                code = "1",
                row = "3",
                col = "23",
                end_col = 24,
                severity = 2,
                message = "Command terminated with space.",
            }, diagnostic)
        end)
    end)

    describe("credo", function()
        local linter = diagnostics.credo
        local parser = linter._opts.on_output
        local credo_diagnostics
        local done = function(_diagnostics)
            credo_diagnostics = _diagnostics
        end
        after_each(function()
            credo_diagnostics = nil
        end)

        it("should create a diagnostic with error severity", function()
            local output = [[
            {
              "issues": [
                {
                  "category": "consistency",
                  "check": "Credo.Check.Consistency.SpaceInParentheses",
                  "column": null,
                  "column_end": null,
                  "filename": "lib/todo_web/controllers/page_controller.ex",
                  "line_no": 4,
                  "message": "There is no whitespace around parentheses/brackets most of the time, but here there is.",
                  "priority": 12,
                  "scope": "TodoWeb.PageController.index",
                  "trigger": "( c"
                }
              ]
            } ]]
            parser({ output = output }, done)
            assert.are.same({
                {
                    source = "credo",
                    message = "There is no whitespace around parentheses/brackets most of the time, but here there is.",
                    row = 4,
                    col = nil,
                    end_col = nil,
                    severity = 1,
                },
            }, credo_diagnostics)
        end)
        it("should create a diagnostic with warning severity", function()
            local output = [[
            {
              "issues": [{
                "category": "readability",
                "check": "Credo.Check.Readability.ImplTrue",
                "column": 3,
                "column_end": 13,
                "filename": "./foo.ex",
                "line_no": 3,
                "message": "@impl true should be @impl MyBehaviour",
                "priority": 8,
                "scope": null,
                "trigger": "@impl true"
              }]
            } ]]
            parser({ output = output }, done)
            assert.are.same({
                {
                    source = "credo",
                    message = "@impl true should be @impl MyBehaviour",
                    row = 3,
                    col = 3,
                    end_col = 13,
                    severity = 2,
                },
            }, credo_diagnostics)
        end)
        it("should create a diagnostic with information severity", function()
            local output = [[
            {
              "issues": [{
                "category": "design",
                "check": "Credo.Check.Design.TagTODO",
                "column": null,
                "column_end": null,
                "filename": "./foo.ex",
                "line_no": 8,
                "message": "Found a TODO tag in a comment: \"TODO: implement check\"",
                "priority": -5,
                "scope": null,
                "trigger": "TODO: implement check"
              }]
            } ]]
            parser({ output = output }, done)
            assert.are.same({
                {
                    source = "credo",
                    message = 'Found a TODO tag in a comment: "TODO: implement check"',
                    row = 8,
                    col = nil,
                    end_col = nil,
                    severity = 3,
                },
            }, credo_diagnostics)
        end)
        it("should create a diagnostic falling back to hint severity", function()
            local output = [[
            {
              "issues": [{
                "category": "refactor",
                "check": "Credo.Check.Refactor.FilterFilter",
                "column": null,
                "column_end": null,
                "filename": "./foo.ex",
                "line_no": 12,
                "message": "One `Enum.filter/2` is more efficient than `Enum.filter/2 |> Enum.filter/2`",
                "priority": -15,
                "scope": null,
                "trigger": "|>"
              }]
            } ]]
            parser({ output = output }, done)
            assert.are.same({
                {
                    source = "credo",
                    message = "One `Enum.filter/2` is more efficient than `Enum.filter/2 |> Enum.filter/2`",
                    row = 12,
                    col = nil,
                    end_col = nil,
                    severity = 4,
                },
            }, credo_diagnostics)
        end)
        it("returns errors as diagnostics", function()
            local error =
                [[** (Mix) The task "credo" could not be found\nNote no mix.exs was found in the current directory]]
            parser({ err = error }, done)
            assert.are.same({
                {
                    source = "credo",
                    message = error,
                    row = 1,
                },
            }, credo_diagnostics)
        end)
        it("should handle compile warnings preceeding output", function()
            local output = [[
            00:00:00.000 [warn] IMPORTING DEV.SECRET

            {
              "issues": [
                {
                  "category": "consistency",
                  "check": "Credo.Check.Consistency.SpaceInParentheses",
                  "column": null,
                  "column_end": null,
                  "filename": "lib/todo_web/controllers/page_controller.ex",
                  "line_no": 4,
                  "message": "There is no whitespace around parentheses/brackets most of the time, but here there is.",
                  "priority": 12,
                  "scope": "TodoWeb.PageController.index",
                  "trigger": "( c"
                }
              ]
            } ]]
            parser({ output = output }, done)
            assert.are.same({
                {
                    source = "credo",
                    message = "There is no whitespace around parentheses/brackets most of the time, but here there is.",
                    row = 4,
                    col = nil,
                    end_col = nil,
                    severity = 1,
                },
            }, credo_diagnostics)
        end)
        it("should handle messages with incomplete json", function()
            local output = [[Some incomplete message that shouldn't really happen { "issues": ]]
            parser({ output = output }, done)
            assert.are.same({
                {
                    source = "credo",
                    message = output,
                    row = 1,
                },
            }, credo_diagnostics)
        end)
        it("should handle messages without json", function()
            local output = [[Another message that shouldn't really happen]]
            parser({ output = output }, done)
            assert.are.same({
                {
                    source = "credo",
                    message = output,
                    row = 1,
                },
            }, credo_diagnostics)
        end)
    end)

    describe("luacheck", function()
        local linter = diagnostics.luacheck
        local parser = linter._opts.on_output
        local file = {
            [[sx = {]],
        }

        it("should create a diagnostic", function()
            local output = [[test.lua:2:1-1: (E011) expected expression near <eof>]]
            local diagnostic = parser(output, { content = file })
            assert.are.same({
                code = "011",
                row = "2",
                col = "1",
                end_col = 2,
                severity = 1,
                message = "expected expression near <eof>",
            }, diagnostic)
        end)
    end)

    describe("write-good", function()
        local linter = diagnostics.write_good
        local parser = linter._opts.on_output
        local file = {
            [[Any rule whose heading is ~~struck through~~ is deprecated, but still provided for backward-compatibility.]],
        }

        it("should create a diagnostic", function()
            local output = [[rules.md:1:46:"is deprecated" may be passive voice]]
            local diagnostic = parser(output, { content = file })
            assert.are.same({
                row = "1", --
                col = 47,
                end_col = 59,
                severity = 1,
                message = '"is deprecated" may be passive voice',
            }, diagnostic)
        end)
    end)

    describe("markdownlint", function()
        local linter = diagnostics.markdownlint
        local parser = linter._opts.on_output
        local file = {
            [[<a name="md001"></a>]],
            [[]],
        }

        it("should create a diagnostic with a column", function()
            local output = "rules.md:1:1 MD033/no-inline-html Inline HTML [Element: a]"
            local diagnostic = parser(output, { content = file })
            assert.are.same({
                code = "MD033/no-inline-html",
                row = "1",
                col = "1",
                severity = 1,
                message = "Inline HTML [Element: a]",
            }, diagnostic)
        end)
        it("should create a diagnostic without a column", function()
            local output =
                "rules.md:2 MD012/no-multiple-blanks Multiple consecutive blank lines [Expected: 1; Actual: 2]"
            local diagnostic = parser(output, { content = file })
            assert.are.same({
                row = "2",
                code = "MD012/no-multiple-blanks",
                severity = 1,
                message = "Multiple consecutive blank lines [Expected: 1; Actual: 2]",
            }, diagnostic)
        end)
    end)

    describe("mdl", function()
        local linter = diagnostics.mdl
        local parser = linter._opts.on_output

        it("should create a diagnostic", function()
            local output = vim.json.decode([[
              [
                {
                  "filename": "rules.md",
                  "line": 1,
                  "rule": "MD022",
                  "aliases": [
                    "blanks-around-headers"
                  ],
                  "description": "Headers should be surrounded by blank lines"
                }
              ]
            ]])
            local diagnostic = parser({ output = output })
            assert.are.same({
                {
                    code = "MD022",
                    row = 1,
                    severity = 2,
                    message = "Headers should be surrounded by blank lines",
                },
            }, diagnostic)
        end)
    end)

    describe("tl check", function()
        local linter = diagnostics.teal
        local parser = linter._opts.on_output
        local file = {
            [[require("settings").load_options()]],
            "vim.cmd [[",
            [[local command = table.concat(vim.tbl_flatten { "autocmd", def }, " ")]],
        }

        it("should create a diagnostic (quote field is between quotes)", function()
            local output = [[init.lua:1:8: module not found: 'settings']]
            local diagnostic = parser(output, { content = file })
            assert.are.same({
                row = "1", --
                col = "8",
                end_col = 17,
                severity = 1,
                message = "module not found: 'settings'",
                source = "tl check",
            }, diagnostic)
        end)
        it("should create a diagnostic (quote field is not between quotes)", function()
            local output = [[init.lua:2:1: unknown variable: vim]]
            local diagnostic = parser(output, { content = file })
            assert.are.same({
                row = "2", --
                col = "1",
                end_col = 3,
                severity = 1,
                message = "unknown variable: vim",
                source = "tl check",
            }, diagnostic)
        end)
        it("should create a diagnostic by using the second pattern", function()
            local output = [[autocmds.lua:3:46: argument 1: got <unknown type>, expected {string}]]
            local diagnostic = parser(output, { content = file })
            assert.are.same({
                row = "3", --
                col = "46",
                severity = 1,
                message = "argument 1: got <unknown type>, expected {string}",
                source = "tl check",
            }, diagnostic)
        end)
    end)

    describe("shellcheck", function()
        local linter = diagnostics.shellcheck
        local parser = linter._opts.on_output

        it("should create a diagnostic with info severity", function()
            local output = vim.json.decode([[
            {
              "comments": [{
                "file": "./OpenCast.sh",
                "line": 21,
                "endLine": 21,
                "column": 8,
                "endColumn": 37,
                "level": "info",
                "code": 1091,
                "message": "Not following: script/cli_builder.sh was not specified as input (see shellcheck -x).",
                "fix": null
              }]
            } ]])
            local diagnostic = parser({ output = output })
            assert.are.same({
                {
                    code = 1091,
                    row = 21,
                    end_row = 21,
                    col = 8,
                    end_col = 37,
                    severity = 3,
                    message = "Not following: script/cli_builder.sh was not specified as input (see shellcheck -x).",
                },
            }, diagnostic)
        end)
        it("should create a diagnostic with style severity", function()
            local output = vim.json.decode([[
            {
              "comments": [{
                "file": "./OpenCast.sh",
                "line": 21,
                "endLine": 21,
                "column": 8,
                "endColumn": 37,
                "level": "style",
                "code": 1091,
                "message": "Not following: script/cli_builder.sh was not specified as input (see shellcheck -x).",
                "fix": null
              }]
            } ]])
            local diagnostic = parser({ output = output })
            assert.are.same({
                {
                    code = 1091,
                    row = 21,
                    end_row = 21,
                    col = 8,
                    end_col = 37,
                    severity = 4,
                    message = "Not following: script/cli_builder.sh was not specified as input (see shellcheck -x).",
                },
            }, diagnostic)
        end)
    end)

    describe("selene", function()
        local linter = diagnostics.selene
        local parser = linter._opts.on_output
        local file = {
            "vim.cmd [[",
            [[CACHE_PATH = vim.fn.stdpath "cache"]],
        }

        it("should create a diagnostic (quote is between backquotes)", function()
            local output = [[init.lua:1:1: error[undefined_variable]: `vim` is not defined]]
            local diagnostic = parser(output, { content = file })
            assert.are.same({
                row = "1", --
                col = "1",
                end_col = 4,
                severity = 1,
                code = "undefined_variable",
                message = "`vim` is not defined",
            }, diagnostic)
        end)
        it("should create a diagnostic (quote is not between backquotes)", function()
            local output =
                [[lua/default-config.lua:2:1: warning[unused_variable]: CACHE_PATH is defined, but never used]]
            local diagnostic = parser(output, { content = file })
            assert.are.same({
                row = "2", --
                col = "1",
                end_col = 11,
                severity = 2,
                code = "unused_variable",
                message = "CACHE_PATH is defined, but never used",
            }, diagnostic)
        end)
    end)

    describe("eslint", function()
        local linter = diagnostics.eslint
        local parser = linter._opts.on_output

        it("should create a diagnostic with warning severity", function()
            local output = vim.json.decode([[
            [{
              "filePath": "/home/luc/Projects/Pi-OpenCast/webapp/src/index.js",
              "messages": [
                {
                  "ruleId": "quotes",
                  "severity": 1,
                  "message": "Strings must use singlequote.",
                  "line": 1,
                  "column": 19,
                  "nodeType": "Literal",
                  "messageId": "wrongQuotes",
                  "endLine": 1,
                  "endColumn": 26,
                  "fix": {
                    "range": [
                      18,
                      25
                    ],
                    "text": "'react'"
                  }
                }
              ]
            }] ]])
            local diagnostic = parser({ output = output })
            assert.are.same({
                {
                    row = 1, --
                    end_row = 1,
                    col = 19,
                    end_col = 26,
                    severity = 2,
                    code = "quotes",
                    message = "Strings must use singlequote.",
                },
            }, diagnostic)
        end)
        it("should create a diagnostic with error severity", function()
            local output = vim.json.decode([[
            [{
              "filePath": "/home/luc/Projects/Pi-OpenCast/webapp/src/index.js",
              "messages": [
                {
                  "ruleId": "quotes",
                  "severity": 2,
                  "message": "Strings must use singlequote.",
                  "line": 1,
                  "column": 19,
                  "nodeType": "Literal",
                  "messageId": "wrongQuotes",
                  "endLine": 1,
                  "endColumn": 26,
                  "fix": {
                    "range": [
                      18,
                      25
                    ],
                    "text": "'react'"
                  }
                }
              ]
            }] ]])
            local diagnostic = parser({ output = output })
            assert.are.same({
                {
                    row = 1, --
                    end_row = 1,
                    col = 19,
                    end_col = 26,
                    severity = 1,
                    code = "quotes",
                    message = "Strings must use singlequote.",
                },
            }, diagnostic)
        end)
    end)

    describe("standardjs", function()
        local linter = diagnostics.standardjs
        local parser = linter._opts.on_output

        it("should create a diagnostic with error severity", function()
            local file = {
                [[export const foo = () => { return 'hello']],
            }
            local output = [[rules.js:1:2: Parsing error: Unexpected token]]
            local diagnostic = parser(output, { content = file })
            assert.are.same({
                row = "1", --
                col = "2",
                severity = 1,
                message = "Unexpected token",
            }, diagnostic)
        end)
        it("should create a diagnostic with warning severity", function()
            local file = {
                [[export const foo = () => { return "hello" }]],
            }
            local output = [[rules.js:1:35: Strings must use singlequote.]]
            local diagnostic = parser(output, { content = file })
            assert.are.same({
                row = "1", --
                col = "35",
                severity = 2,
                message = "Strings must use singlequote.",
            }, diagnostic)
        end)
    end)

    describe("hadolint", function()
        local linter = diagnostics.hadolint
        local parser = linter._opts.on_output

        it("should create a diagnostic with warning severity", function()
            local output = vim.json.decode([[
                  [{
                    "line": 24,
                    "code": "DL3008",
                    "message": "Pin versions in apt get install. Instead of `apt-get install <package>` use `apt-get install <package>=<version>`",
                    "column": 1,
                    "file": "/home/luc/Projects/Test/buildroot/support/docker/Dockerfile",
                    "level": "warning"
                  }]
            ]])
            local diagnostic = parser({ output = output })
            assert.are.same({
                {
                    row = 24, --
                    col = 1,
                    severity = 2,
                    code = "DL3008",
                    message = "Pin versions in apt get install. Instead of `apt-get install <package>` use `apt-get install <package>=<version>`",
                },
            }, diagnostic)
        end)
        it("should create a diagnostic with info severity", function()
            local output = vim.json.decode([[
                  [{
                    "line": 24,
                    "code": "DL3059",
                    "message": "Multiple consecutive `RUN` instructions. Consider consolidation.",
                    "column": 1,
                    "file": "/home/luc/Projects/Test/buildroot/support/docker/Dockerfile",
                    "level": "info"
                  }]
            ]])
            local diagnostic = parser({ output = output })
            assert.are.same({
                {
                    row = 24, --
                    col = 1,
                    severity = 3,
                    code = "DL3059",
                    message = "Multiple consecutive `RUN` instructions. Consider consolidation.",
                },
            }, diagnostic)
        end)
    end)

    describe("flake8", function()
        local linter = diagnostics.flake8
        local parser = linter._opts.on_output
        local file = {
            [[#===- run-clang-tidy.py - Parallel clang-tidy runner ---------*- python -*--===#]],
        }

        it("should create a diagnostic", function()
            local output = [[run-clang-tidy.py:3:1: E265 block comment should start with '# ']]
            local diagnostic = parser(output, { content = file })
            assert.are.same({
                row = "3", --
                col = "1",
                severity = 1,
                code = "E265",
                message = "block comment should start with '# '",
            }, diagnostic)
        end)
    end)

    describe("misspell", function()
        local linter = diagnostics.misspell
        local parser = linter._opts.on_output
        local file = {
            [[Did I misspell langauge ?]],
        }

        it("should create a diagnostic", function()
            local output = [[stdin:1:15: "langauge" is a misspelling of "language"]]
            local diagnostic = parser(output, { content = file })
            assert.are.same({
                row = "1",
                col = 16,
                severity = 3,
                message = [["langauge" is a misspelling of "language"]],
            }, diagnostic)
        end)
    end)

    describe("vint", function()
        local linter = diagnostics.vint
        local parser = linter._opts.on_output

        it("should create a diagnostic with warning severity", function()
            local output = vim.json.decode([[
                  [{
                    "file_path": "/home/luc/Projects/Test/vim-scriptease/plugin/scriptease.vim",
                    "line_number": 5,
                    "column_number": 37,
                    "severity": "style_problem",
                    "description": "Use the full option name `compatible` instead of `cp`",
                    "policy_name": "ProhibitAbbreviationOption",
                    "reference": ":help option-summary"
                  }]
            ]])
            local diagnostic = parser({ output = output })
            assert.are.same({
                {
                    row = 5, --
                    col = 37,
                    severity = 3,
                    code = "ProhibitAbbreviationOption",
                    message = "Use the full option name `compatible` instead of `cp`",
                },
            }, diagnostic)
        end)
    end)

    describe("yamllint", function()
        local linter = diagnostics.yamllint
        local parser = linter._opts.on_output
        local file = {
            [[true]],
        }

        it("should create a diagnostic with warning severity", function()
            local output = [[stdin:1:1: [warning] missing document start "---" (document-start)]]
            local diagnostic = parser(output, { content = file })
            assert.are.same({
                row = "1", --
                col = "1",
                severity = 2,
                code = "document-start",
                message = 'missing document start "---"',
            }, diagnostic)
        end)
    end)

    describe("jsonlint", function()
        local linter = diagnostics.jsonlint
        local parser = linter._opts.on_output
        local file = {
            [[{ "name"* "foo" }]],
        }

        it("should create a diagnostic", function()
            local output = [[rules.json: line 1, col 8, found: 'INVALID' - expected: 'EOF', '}', ':', ',', ']'.]]
            local diagnostic = parser(output, { content = file })
            assert.are.same({
                row = "1", --
                col = "8",
                severity = 1,
                message = "found: 'INVALID' - expected: 'EOF', '}', ':', ',', ']'.",
            }, diagnostic)
        end)
    end)

    describe("cue_fmt", function()
        local linter = diagnostics.cue_fmt
        local parser = linter._opts.on_output
        local cue_fmt_diagnostics
        local done = function(_diagnostics)
            cue_fmt_diagnostics = _diagnostics
        end

        it("should create a diagnostic", function()
            local output = vim.trim([[
            expected label or ':', found 'INT' 42:
                ../../../../../../../tmp/null-ls_GLJOFJ.cue:3:2
            ]])
            parser({ output = output }, done)
            assert.are.same({
                {
                    row = "3",
                    col = "2",
                    end_col = 3,
                    severity = 1,
                    message = "expected label or ':', found 'INT' 42:",
                    source = "cue_fmt",
                },
            }, cue_fmt_diagnostics)
        end)
    end)
end)
