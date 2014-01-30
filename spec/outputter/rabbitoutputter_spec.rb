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

  describe "#start_bunny" do
    before do
      @bunny_client = double(:bunny).as_null_object
      Bunny.stub(:new).and_return(@bunny_client)
    end

    it "uses the outputter config to initialize a Bunny client" do
      config = {some: "config"}
      subject.instance_variable_set(:@config, config)
      Bunny.should_receive(:new).with(config)
      subject.start_bunny
    end

    it "starts the Bunny client" do
      @bunny_client.should_receive(:start)
      subject.start_bunny
    end

    it "calls create_channel" do
      subject.should_receive(:create_channel)
      subject.start_bunny
    end

    context "when an exception occurs" do
      it "handles Bunny::TCPConnectionFailed" do
        @bunny_client.stub(:start).and_raise(Bunny::TCPConnectionFailed.new(double, double, double))
        expect { subject.start_bunny }.to_not raise_error
      end

      it "handles generic exception" do
        subject.stub(:create_channel).and_raise
        expect { subject.start_bunny }.to_not raise_error
      end
    end
  end

  describe "#write" do
    context "when the outputter has a valid connection" do
      before do
        @bunny_client = double(:conn).as_null_object
        subject.instance_variable_set(:@conn, @bunny_client)
        subject.instance_variable_set(:@queue, double(:queue).as_null_object)
      end

      it "calls @queue.publish when the Bunny client is connected and @queue is not nil" do
        @bunny_client.stub(:connect?).and_return(true)
        subject.instance_variable_get(:@queue).should_receive(:publish)
        subject.send(:write, "")
      end

      it "does not raise an exception when @queue.publish raises an exception" do
        subject.instance_variable_get(:@queue).stub(:publish).and_raise(Exception.new)
        expect { subject.send(:write, "") }.to_not raise_error
      end

      it "does not raise an exception when @queue is nil" do
        @bunny_client.stub(:connect?).and_return(true)
        subject.instance_variable_set(:@queue, nil)
        subject.send(:write, "")
      end

      it "does not call publish when the Bunny client is not connected" do
        @bunny_client.stub(:connect?).and_return(false)
        subject.instance_variable_get(:@queue).should_not_receive(:publish)
        subject.send(:write, "")
      end
    end

    context "when the outputter does not have a valid connection" do
      before do
        subject.instance_variable_set(:@conn, @bunny_client)
      end

      it "does not call publish on @queue" do
        subject.instance_variable_get(:@queue).should_not_receive(:publish)
        subject.send(:write, "")
      end

      it "attempts to re-establish a connection by calling start_bunny" do
        subject.should_receive(:start_bunny)
        subject.send(:write, "")
      end
    end
  end
end