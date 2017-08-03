# frozen_string_literal: true

require_relative 'integration_helper'
require 'json'

def build_catalogs(old_repo, new_repo, argv)
  result = OctocatalogDiff::Integration.integration(
    spec_repo_old: old_repo,
    spec_repo_new: new_repo,
    spec_fact_file: 'valid-facts.yaml',
    argv: argv
  )
  [result, OctocatalogDiff::Integration.format_exception(result)]
end

describe 'ignore-tags integration' do
  context 'with --ignore-tags specified but not matching' do
    before(:all) do
      argv = ['--ignore-tags', 'asdlfkadsfasfqwefadsfsaf']
      @result, @exception_message = build_catalogs('ignore-tags-old', 'ignore-tags-new', argv)
      @diffs = OctocatalogDiff::Spec.remove_file_and_line(@result[:diffs])
    end

    let(:answer) { JSON.parse(File.read(OctocatalogDiff::Spec.fixture_path('diffs/ignore-tags-full.json'))) }

    it 'should succeed' do
      expect(@result[:exitcode]).not_to eq(-1), @exception_message
      expect(@result[:exitcode]).to eq(2), "Runtime error: #{@result[:logs]}"
      expect(@diffs).to be_a_kind_of(Array)
    end

    it 'should have the correct catalog-diff result' do
      pending 'catalog-diff failed' unless @result[:exitcode] == 2
      expect(@diffs.size).to eq(30)
      expect(answer.size).to eq(30) # It's a fixture, but verify that it loaded correctly.
      diff_indexed = @diffs.map { |x| [x[0], x[1]] }
      answer_indexed = answer.map { |x| [x[0], x[1]] }
      answer_indexed.each do |x|
        expect(diff_indexed).to include(x), "Does not contain: #{x}"
      end
    end
  end

  context 'with --ignore-tags specified and matching' do
    before(:all) do
      argv = ['--ignore-tags', 'ignored_catalog_diff']
      @result, @exception_message = build_catalogs('ignore-tags-old', 'ignore-tags-new', argv)
      @diffs = OctocatalogDiff::Spec.remove_file_and_line(@result[:diffs])
    end

    let(:answer) { JSON.parse(File.read(OctocatalogDiff::Spec.fixture_path('diffs/ignore-tags-partial.json'))) }

    it 'should succeed' do
      expect(@result[:exitcode]).not_to eq(-1), @exception_message
      expect(@result[:exitcode]).to eq(2), "Runtime error: #{@result[:logs]}"
      expect(@diffs).to be_a_kind_of(Array)
    end

    it 'should have the correct length of diffs' do
      pending 'catalog-diff failed' unless @result[:exitcode] == 2
      expect(@diffs.size).to eq(8)
      expect(answer.size).to eq(8) # It's a fixture, but verify that it loaded correctly.
    end

    it 'should have entire catalog-diff result' do
      pending 'catalog-diff failed' unless @result[:exitcode] == 2
      adjusted_answer = OctocatalogDiff::Spec.remove_file_and_line(answer)
      adjusted_answer.each do |x|
        expect(@diffs).to include(x), "Does not contain: #{x}"
      end
    end
  end

  context 'with --ignore-tags specified and old and new reversed' do
    before(:all) do
      argv = ['--ignore-tags', 'ignored_catalog_diff']
      @result, @exception_message = build_catalogs('ignore-tags-new', 'ignore-tags-old', argv)
      @diffs = OctocatalogDiff::Spec.remove_file_and_line(@result[:diffs])
    end

    let(:answer) { JSON.parse(File.read(OctocatalogDiff::Spec.fixture_path('diffs/ignore-tags-reversed.json'))) }

    it 'should succeed' do
      expect(@result[:exitcode]).not_to eq(-1), @exception_message
      expect(@result[:exitcode]).to eq(2), "Runtime error: #{@result[:logs]}"
      expect(@diffs).to be_a_kind_of(Array)
    end

    it 'should have the correct diffs' do
      pending 'catalog-diff failed' unless @result[:exitcode] == 2
      expect(@diffs.size).to eq(12)
      expect(answer.size).to eq(12) # It's a fixture, but verify that it loaded correctly.
      require 'json'
      File.open('/tmp/the-result.json', 'w') { |f| f.write(JSON.pretty_generate(@diffs)) }
      adjusted_answer = OctocatalogDiff::Spec.remove_file_and_line(answer)
      adjusted_answer.each do |x|
        expect(@diffs).to include(x)
      end
    end
  end

  it 'should remove tagged-for-ignore resources' do
    @logger, @logger_str = OctocatalogDiff::Spec.setup_logger
    cat1 = OctocatalogDiff::Catalog.create(json: File.read(OctocatalogDiff::Spec.fixture_path('catalogs/ignore-tags-old.json')))
    cat2 = OctocatalogDiff::Catalog.create(json: File.read(OctocatalogDiff::Spec.fixture_path('catalogs/ignore-tags-new.json')))
    opts = { ignore_tags: ['ignored_catalog_diff'] }
    answer = JSON.parse(File.read(OctocatalogDiff::Spec.fixture_path('diffs/ignore-tags-partial.json')))
    obj = OctocatalogDiff::Cli::Diffs.new(opts, @logger)
    diffs = obj.diffs(from: cat1, to: cat2)
    expect(diffs.size).to eq(8)
    answer.each do |x|
      expect(diffs).to include(x), "Does not contain: #{x}"
    end
    expect(@logger_str.string).to match(/Ignoring type='Mymodule::Resource1', title='one' based on tag in to-catalog/)
    r = %r{Ignoring type='File', title='/tmp/old-file/ignored/one' based on tag in from-catalog}
    expect(@logger_str.string).to match(r)
  end
end
