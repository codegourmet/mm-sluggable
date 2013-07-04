require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "MongoMapper::Plugins::Sluggable" do

  before(:each) do
    @klass = article_class
  end

  describe "with defaults" do
    before(:each) do
      @klass.sluggable :title
      @article = @klass.new(:title => "testing 123")
    end

    it "should add a key called :slug" do
      @article.keys.keys.should include("slug")
    end

    it "should set the slug on validation" do
      lambda{
        @article.valid?
      }.should change(@article, :slug).from(nil).to("testing-123")
    end

    it "should add a version number if the slug conflicts" do
      @klass.create(:title => "testing 123")
      lambda{
        @article.valid?
      }.should change(@article, :slug).from(nil).to("testing-123-1")
    end

    it "should truncate slugs over the max_length default of 256 characters" do
      @article.title = "a" * 300
      @article.valid?
      @article.slug.length.should == 256
    end
  end

  describe "with scope" do
    before(:each) do
      @klass.sluggable :title, :scope => :account_id
      @article = @klass.new(:title => "testing 123", :account_id => 1)
    end

    it "should add a version number if the slug conflics in the scope" do
      @klass.create(:title => "testing 123", :account_id => 1)
      lambda{
        @article.valid?
      }.should change(@article, :slug).from(nil).to("testing-123-1")
    end

    it "should not add a version number if the slug conflicts in a different scope" do
      @klass.create(:title => "testing 123", :account_id => 2)
      lambda{
        @article.valid?
      }.should change(@article, :slug).from(nil).to("testing-123")
    end
  end

  describe "with different key" do
    before(:each) do
      @klass.sluggable :title, :key => :title_slug
      @article = @klass.new(:title => "testing 123")
    end

    it "should add the specified key" do
      @article.keys.keys.should include("title_slug")
    end

    it "should set the slug on validation" do
      lambda{
        @article.valid?
      }.should change(@article, :title_slug).from(nil).to("testing-123")
    end
  end

  describe "with different slugging method" do
    before(:each) do
      @klass.sluggable :title, :method => :upcase
      @article = @klass.new(:title => "testing 123")
    end

    it "should set the slug using the specified method" do
      lambda{
        @article.valid?
      }.should change(@article, :slug).from(nil).to("TESTING 123")
    end
  end

  describe "with a different callback" do
    before(:each) do
      @klass.sluggable :title, :callback => :before_create
      @article = @klass.new(:title => "testing 123")
    end

    it "should not set the slug on the default callback" do
      lambda{
        @article.valid?
      }.should_not change(@article, :slug)
    end

    it "should set the slug on the specified callback" do
      lambda{
        @article.save
      }.should change(@article, :slug).from(nil).to("testing-123")
    end
  end
  
  describe "with custom max_length" do
    before(:each) do
      @klass.sluggable :title, :max_length => 5
      @article = @klass.new(:title => "testing 123")
    end

    it "should truncate slugs over the max length" do
      @article.valid?
      @article.slug.length.should == 5
    end
  end

  describe "with force" do
    before(:each) do
      @klass.sluggable :title, :force => true, :callback => :before_validation
      @article = @klass.create(:title => "testing 123")
    end
    it "should set the slug on force is true and title is changed" do
      lambda{
         @article.title = "changed testing 123"
         @article.valid?
      }.should change(@article, :slug).from("testing-123").to("changed-testing-123")
    end
  end

  describe "with history" do
    before(:each) do
      @klass.sluggable :title, :history => true, callback: :before_save, force: true

      @article_a = @klass.create(:title => "article a")
      @article_a.update_attribute(:title, "article a changed")

      @article_b = @klass.create(:title => "article b")
    end

    it "should store the slug as array" do
      @article_a.slug.class.should eq Array
    end

    it "should add the slug and keep the previous one" do
      @article_a.slug.should eq ["article-a", "article-a-changed"]
    end

    it "should reuse old slugs of the same record" do
      @article_a.update_attribute(:title, "article a")
      @article_a.slug.should eq ["article-a-changed", "article-a"]
    end

    it "should deliver the most recent slug as param" do
      @article_a.to_param.should eq "article-a-changed"
    end

    it "should respect other elements' slug history" do
      @article_a.update_attribute(:slug, ["article-a", "article-a-changed"])
      @article_b.update_attribute(:title, "article a")
      @article_b.slug.should eq ["article-b", "article-a-1"]
    end
  end

  describe "overrided function" do 
    before(:each) do
      @klass.sluggable :title
      @article = @klass.create(:title => "testing 123")
    end
    describe "#to_param" do   
      it "should return the slug" do 
        @article.to_param.should eq @article.slug
      end
      it "should return the id when slug is nil" do 
        @article.stub!(:slug).and_return(nil)
        @article.to_param.should eq @article.id.to_s
      end  
    end   
    describe "#find" do 
      it "should find by slug when call with slug" do 
        @klass.find(@article.slug).should eq @article
      end
      it "should keep origin function" do 
        @klass.find(@article.id).should eq @article
      end 
    end
  end 
end
