require_relative 'helper'

require 'stringio'
require 'tempfile'

class TestPsych < Psych::TestCase
  def teardown
    Psych.domain_types.clear
  end

  def test_load_argument_error
    assert_raises(TypeError) do
      Psych.load nil
    end
  end

  def test_dump_stream
    things = [22, "foo \n", {}]
    stream = Psych.dump_stream(*things)
    assert_equal things, Psych.load_stream(stream)
  end

  def test_dump_file
    hash = {'hello' => 'TGIF!'}
    Tempfile.open('fun.yml') do |io|
      assert_equal io, Psych.dump(hash, io)
      io.rewind
      assert_equal Psych.dump(hash), io.read
    end
  end

  def test_dump_io
    hash = {'hello' => 'TGIF!'}
    stringio = StringIO.new ''
    assert_equal stringio, Psych.dump(hash, stringio)
    assert_equal Psych.dump(hash), stringio.string
  end

  def test_simple
    assert_equal 'foo', Psych.load("--- foo\n")
  end

  def test_libyaml_version
    assert Psych.libyaml_version
    assert_equal Psych.libyaml_version.join('.'), Psych::LIBYAML_VERSION
  end

  def test_load_documents
    docs = Psych.load_documents("--- foo\n...\n--- bar\n...")
    assert_equal %w{ foo bar }, docs
  end

  def test_parse_stream
    docs = Psych.parse_stream("--- foo\n...\n--- bar\n...")
    assert_equal %w{ foo bar }, docs.children.map { |x| x.transform }
  end

  def test_add_builtin_type
    got = nil
    Psych.add_builtin_type 'omap', do |type, val|
      got = val
    end
    Psych.load('--- !!omap hello')
    assert_equal 'hello', got
  ensure
    Psych.remove_type 'omap'
  end

  def test_domain_types
    got = nil
    Psych.add_domain_type 'foo.bar,2002', 'foo' do |type, val|
      got = val
    end

    Psych.load('--- !foo.bar,2002/foo hello')
    assert_equal 'hello', got

    Psych.load("--- !foo.bar,2002/foo\n- hello\n- world")
    assert_equal %w{ hello world }, got

    Psych.load("--- !foo.bar,2002/foo\nhello: world")
    assert_equal({ 'hello' => 'world' }, got)
  end

  def test_load_file
    name = File.join(Dir.tmpdir, 'yikes.yml')
    File.open(name, 'wb') { |f| f.write('--- hello world') }

    assert_equal 'hello world', Psych.load_file(name)
  end

  def test_parse_file
    name = File.join(Dir.tmpdir, 'yikes.yml')
    File.open(name, 'wb') { |f| f.write('--- hello world') }

    assert_equal 'hello world', Psych.parse_file(name).transform
  end

  def test_degenerate_strings
    assert_equal false, Psych.load('    ')
    assert_equal false, Psych.parse('   ')
    assert_equal false, Psych.load('')
    assert_equal false, Psych.parse('')
  end

  def test_callbacks
    types = []
    appender = lambda { |*args| types << args }

    Psych.add_builtin_type('foo', &appender)
    Psych.add_domain_type('example.com,2002', 'foo', &appender)
    Psych.load <<-eoyml
- !tag:yaml.org,2002:foo bar
- !tag:example.com,2002:foo bar
    eoyml

    assert_equal [
      ["tag:yaml.org,2002:foo", "bar"],
      ["tag:example.com,2002:foo", "bar"]
    ], types
  end
end
