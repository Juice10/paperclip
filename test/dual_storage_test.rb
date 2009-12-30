require 'test/helper'
require 'aws/s3'

class DualStorageTest < Test::Unit::TestCase
  context "Using the Dual storage, an attachment" do
    setup do
      AWS::S3::Base.stubs(:establish_connection!)

      rebuild_model :storage => :dual,
                    :bucket => "testing",
                    :path => "/tmp/:attachment/:style/:basename.:extension",
                    :default_path => "/tmp/:attachment/default_avatar.png",
                    :url => "http://images.test.com/testing/:attachment/:style/:basename.:extension",
                    :s3_path => ":attachment/:style/:basename.:extension",
                    :default_url => "http://images.test.com/testing/default_avatar.png",
                    :s3_credentials => {
                      'access_key_id' => "12345",
                      'secret_access_key' => "54321"
                    }
    end

    should "be extended by all the storage modules" do
      assert Dummy.new.avatar.is_a?(Paperclip::Storage::Dual)
    end

    context "when not assigned" do
      setup do
        @dummy = Dummy.new
      end

      should "get the default url" do
        assert_equal "http://images.test.com/testing/default_avatar.png", @dummy.avatar.url
      end

      should "get the default path" do
        assert_equal "/tmp/avatars/default_avatar.png", @dummy.avatar.path
      end

    end

    context "when assigned" do
      setup do
        @file = File.new(File.join(File.dirname(__FILE__), 'fixtures', '5k.png'))
        @dummy = Dummy.new
        @dummy.avatar = @file
      end

      should "get the url" do
        assert_match %r{^http://images.test.com/testing/avatars/original/5k\.png}, @dummy.avatar.url
      end

      should "get the path" do
        assert_match %r{^/tmp/avatars/original/5k\.png}, @dummy.avatar.path
      end

      context "and saved" do
        setup do
          AWS::S3::S3Object.expects(:store).with(@dummy.avatar.path, anything, 'testing', :content_type => 'image/png', :access => :public_read)
          @dummy.save
        end

        should "be on S3" do
          assert true
        end

        should "be committed on disk" do
          io = @dummy.avatar.to_io(:original)
          assert File.exists?(io)
          assert !io.is_a?(::Tempfile)
        end

        should "still get the url" do
          assert_match %r{^http://images.test.com/testing/avatars/original/5k\.png}, @dummy.avatar.url
        end

        should "still get the path" do
          assert_match %r{^/tmp/avatars/original/5k\.png}, @dummy.avatar.path
        end

        context "and then removed" do
          setup do
            AWS::S3::S3Object.expects(:delete).with('avatars/original/5k.png', 'testing')
            @dummy.destroy_attached_files
          end

          should "succeed" do
            assert true
          end

          should "not be on disk anymore" do
            assert !@dummy.avatar.to_io(:original)
          end
        end
      end
    end
  end
end