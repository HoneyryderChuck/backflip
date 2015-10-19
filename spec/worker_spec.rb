require 'spec_helper'
require 'backflip/worker'

RSpec.describe Backflip::Worker do
  subject { described_class.new }
  after { subject.terminate }

  MockWorker = Class.new do
    include Backflip::Job
    def perform
    end
  end
  
  let(:job) { double(:job, message: dump, queue_name: "default") }
  let(:dump) { Sidekiq.dump_json({ 'class' => MockWorker.name, 'args'=> [] }) } 

  it "performs work" do
    expect_any_instance_of(MockWorker).to receive(:perform) 
    expect(job).to receive(:signal)

    subject.do!(job)
  end 
end
