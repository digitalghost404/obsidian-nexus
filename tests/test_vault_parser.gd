# tests/test_vault_parser.gd
extends GdUnitTestSuite

const VaultParser = preload("res://autoloads/vault_parser.gd")

var parser: VaultParser

func before() -> void:
	parser = VaultParser.new()

func after() -> void:
	parser.free()

func test_parse_frontmatter() -> void:
	var content := """---
title: Test Note
tags: [devops, security]
---
# Body content here

Some text with a [[linked note]] inside.
"""
	var result := parser.parse_note(content, "test-folder/Test Note.md")

	assert_str(result.title).is_equal("Test Note")
	assert_array(result.tags).contains_exactly(["devops", "security"])
	assert_str(result.folder).is_equal("test-folder")

func test_parse_wikilinks() -> void:
	var content := """---
title: Links Test
---
Check out [[Note A]] and also [[folder/Note B]] for details.
And [[Note A]] again (should dedupe).
"""
	var result := parser.parse_note(content, "Links Test.md")

	assert_array(result.outgoing_links).contains_exactly(["Note A", "folder/Note B"])

func test_parse_inline_tags() -> void:
	var content := """Some text with #inline-tag and #another-tag here.
And a #third-tag on line 2.
"""
	var result := parser.parse_note(content, "Tag Test.md")

	assert_array(result.tags).contains_exactly(["inline-tag", "another-tag", "third-tag"])

func test_word_count() -> void:
	var content := """---
title: Word Count Test
---
One two three four five six seven eight nine ten.
"""
	var result := parser.parse_note(content, "Word Count Test.md")

	assert_int(result.word_count).is_equal(10)

func test_title_fallback_to_filename() -> void:
	var content := "Just body text, no frontmatter."
	var result := parser.parse_note(content, "some-folder/My Note.md")

	assert_str(result.title).is_equal("My Note")
	assert_str(result.folder).is_equal("some-folder")
