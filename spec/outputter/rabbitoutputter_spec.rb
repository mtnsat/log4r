require 'spec_helper'

# TODO: Refactor this out at some point:
# Required because RabbitOutputter is expecting log4r getting used in a rails app
class Log4r::RabbitOutputter::Rails
end

# TODO: Refactor this out at some point:
# Required because RabbitOutputter is expecting to have HashWithIndifferenceAccess
class Hash
  def symbolize_keys!
  end
end

describe "Log4r::RabbitOutputter" do
  subject { Log4r::RabbitOutputter.new("rabbit_outputter") }
  before do
    Log4r::RabbitOutputter::Rails.stub(:root).and_return("/some/path")
  end

  it "can be initialized" do
    expect { Log4r::RabbitOutputter.new("rabbit_outputter") }.to_not raise_error
  end

  describe "#write" do
    context "when the outputter has a valid connection" do
      before do
        subject.instance_variable_set(:@conn, double(:conn).as_null_object)
        subject.instance_variable_get(:@queue).stub(:publish).and_raise(Exception.new)
      end

      it "does not throw an exception if the @queue.publish throws an exception" do
        expect { subject.send(:write, "") }.to_not raise_error
      end
    end

    context "when the outputter does not have a valid connection" do
      before do
        subject.instance_variable_get(:@queue).stub(:publish).and_raise(Exception.new)
      end

      it "does not throw an exception" do
        expect { subject.send(:write, "") }.to_not raise_error
      end

      it "attempts to re-establish a connection by calling start_bunny" do
        subject.should_receive(:start_bunny)
        subject.send(:write, "")
      end
    end
  end
end