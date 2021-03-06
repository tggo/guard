require 'spec_helper'
require 'guard/guard'

describe Guard::Watcher do

  describe "#initialize" do
    it "requires a pattern parameter" do
      expect { described_class.new }.to raise_error(ArgumentError)
    end

    context "with a pattern parameter" do
      context "that is a string" do
        it "keeps the string pattern unmodified" do
          described_class.new('spec_helper.rb').pattern.should == 'spec_helper.rb'
        end
      end

      context "that is a regexp" do
        it "keeps the regex pattern unmodified" do
          described_class.new(/spec_helper\.rb/).pattern.should == /spec_helper\.rb/
        end
      end

      context "that is a string looking like a regex (deprecated)" do
        before(:each) { Guard::UI.should_receive(:info).any_number_of_times }

        it "converts the string automatically to a regex" do
          described_class.new('^spec_helper.rb').pattern.should == /^spec_helper.rb/
          described_class.new('spec_helper.rb$').pattern.should == /spec_helper.rb$/
          described_class.new('spec_helper\.rb').pattern.should == /spec_helper\.rb/
          described_class.new('.*_spec.rb').pattern.should == /.*_spec.rb/
        end
      end
    end
  end

  describe "#action" do
    it "sets the action to nothing by default" do
      described_class.new(/spec_helper\.rb/).action.should be_nil
    end

    it "sets the action to the supplied block" do
      action = lambda { |m| "spec/#{m[1]}_spec.rb" }
      described_class.new(%r{^lib/(.*).rb}, action).action.should == action
    end
  end

  describe ".match_files" do
    before(:all) { @guard = Guard::Guard.new }

    context "with a watcher without action" do
      context "that is a regex pattern" do
        before(:all) { @guard.watchers = [described_class.new(/.*_spec\.rb/)] }

        it "returns the paths that matches the regex" do
          described_class.match_files(@guard, ['guard_rocks_spec.rb', 'guard_rocks.rb']).should == ['guard_rocks_spec.rb']
        end
      end

      context "that is a string pattern" do
        before(:all) { @guard.watchers = [described_class.new('guard_rocks_spec.rb')] }

        it "returns the path that matches the string" do
          described_class.match_files(@guard, ['guard_rocks_spec.rb', 'guard_rocks.rb']).should == ['guard_rocks_spec.rb']
        end
      end
    end

    context "with a watcher action without parameter" do
      before(:all) do
        @guard.watchers = [
          described_class.new('spec_helper.rb', lambda { 'spec' }),
          described_class.new('addition.rb',    lambda { 1 + 1 }),
          described_class.new('hash.rb',        lambda { Hash[:foo, 'bar'] }),
          described_class.new('array.rb',       lambda { ['foo', 'bar'] }),
          described_class.new('blank.rb',       lambda { '' }),
          described_class.new(/^uptime\.rb/,    lambda { `uptime > /dev/null` })
        ]
      end

      it "returns a single file specified within the action" do
        described_class.match_files(@guard, ['spec_helper.rb']).should == ['spec']
      end

      it "returns multiple files specified within the action" do
        described_class.match_files(@guard, ['hash.rb']).should == ['foo', 'bar']
      end

      it "returns multiple files by combining the results of different actions" do
        described_class.match_files(@guard, ['spec_helper.rb', 'array.rb']).should == ['spec', 'foo', 'bar']
      end

      it "returns nothing if the action returns something other than a string or an array of strings" do
        described_class.match_files(@guard, ['addition.rb']).should == []
      end

      it "returns nothing if the action response is empty" do
        described_class.match_files(@guard, ['blank.rb']).should == []
      end

      it "returns nothing if the action returns nothing" do
        described_class.match_files(@guard, ['uptime.rb']).should == []
      end
    end

    context "with a watcher action that takes a parameter" do
      before(:all) do
        @guard.watchers = [
          described_class.new(%r{lib/(.*)\.rb},   lambda { |m| "spec/#{m[1]}_spec.rb" }),
          described_class.new(/addition(.*)\.rb/, lambda { |m| 1 + 1 }),
          described_class.new('hash.rb',          lambda { Hash[:foo, 'bar'] }),
          described_class.new(/array(.*)\.rb/,    lambda { |m| ['foo', 'bar'] }),
          described_class.new(/blank(.*)\.rb/,    lambda { |m| '' }),
          described_class.new(/uptime(.*)\.rb/,   lambda { |m| `uptime > /dev/null` })
        ]
      end

      it "returns a substituted single file specified within the action" do
        described_class.match_files(@guard, ['lib/my_wonderful_lib.rb']).should == ['spec/my_wonderful_lib_spec.rb']
      end

      it "returns multiple files specified within the action" do
        described_class.match_files(@guard, ['hash.rb']).should == ['foo', 'bar']
      end

      it "returns multiple files by combining the results of different actions" do
        described_class.match_files(@guard, ['lib/my_wonderful_lib.rb', 'array.rb']).should == ['spec/my_wonderful_lib_spec.rb', 'foo', 'bar']
      end

      it "returns nothing if the action returns something other than a string or an array of strings" do
        described_class.match_files(@guard, ['addition.rb']).should == []
      end

      it "returns nothing if the action response is empty" do
        described_class.match_files(@guard, ['blank.rb']).should == []
      end

      it "returns nothing if the action returns nothing" do
        described_class.match_files(@guard, ['uptime.rb']).should == []
      end
    end

    context "with an exception that is raised" do
      before(:all) { @guard.watchers = [described_class.new('evil.rb', lambda { raise "EVIL" })] }

      it "displays the error and backtrace" do
        Guard::UI.should_receive(:error) { |msg|
          msg.should include("Problem with watch action!")
          msg.should include("EVIL")
        }

        described_class.match_files(@guard, ['evil.rb'])
      end
    end
  end

  describe ".match_files?" do
    before(:all) do
      @guard1 = Guard::Guard.new([described_class.new(/.*_spec\.rb/)])
      @guard2 = Guard::Guard.new([described_class.new('spec_helper.rb', 'spec')])
      @guards = [@guard1, @guard2]
    end

    context "with a watcher that matches a file" do
      specify { described_class.match_files?(@guards, ['lib/my_wonderful_lib.rb', 'guard_rocks_spec.rb']).should be_true }
    end

    context "with no watcher that matches a file" do
      specify { described_class.match_files?(@guards, ['lib/my_wonderful_lib.rb']).should be_false }
    end
  end

  describe "#match_file?" do
    context "with a string pattern" do
      context "that is a normal string" do
        subject { described_class.new('guard_rocks_spec.rb') }

        context "with a watcher that matches a file" do
          specify { subject.match_file?('guard_rocks_spec.rb').should be_true }
        end

        context "with no watcher that matches a file" do
          specify { subject.match_file?('lib/my_wonderful_lib.rb').should be_false }
        end
      end

      context "that is a string representing a regexp (deprecated)" do
        subject { described_class.new('^guard_rocks_spec\.rb$') }

        context "with a watcher that matches a file" do
          specify { subject.match_file?('guard_rocks_spec.rb').should be_true }
        end

        context "with no watcher that matches a file" do
          specify { subject.match_file?('lib/my_wonderful_lib.rb').should be_false }
        end
      end
    end

    context "that is a regexp pattern" do
      subject { described_class.new(/.*_spec\.rb/) }

      context "with a watcher that matches a file" do
        specify { subject.match_file?('guard_rocks_spec.rb').should be_true }
      end

      context "with no watcher that matches a file" do
        specify { subject.match_file?('lib/my_wonderful_lib.rb').should be_false }
      end
    end
  end

  describe ".match_guardfile?" do
    before(:all) { Guard::Dsl.stub(:guardfile_path) { Dir.pwd + '/Guardfile' } }

    context "with files that match the Guardfile" do
      specify { described_class.match_guardfile?(['Guardfile', 'guard_rocks_spec.rb']).should be_true }
    end

    context "with no files that match the Guardfile" do
      specify { described_class.match_guardfile?(['guard_rocks.rb', 'guard_rocks_spec.rb']).should be_false }
    end
  end

end
