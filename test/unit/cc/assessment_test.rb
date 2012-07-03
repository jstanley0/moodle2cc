require 'nokogiri'
require 'minitest/autorun'
require 'test/test_helper'
require 'moodle2cc'

class TestUnitCCAssessment < MiniTest::Unit::TestCase
  include TestHelper

  def setup
    convert_moodle_backup
    @mod = @backup.course.mods.find { |m| m.mod_type == "quiz" }
    @assessment = Moodle2CC::CC::Assessment.new @mod
  end

  def teardown
    clean_tmp_folder
  end

  def test_it_converts_id
    @mod.id = 321
    assessment = Moodle2CC::CC::Assessment.new @mod
    assert_equal 321, assessment.id
  end

  def test_it_converts_title
    @mod.name = "First Quiz"
    assessment = Moodle2CC::CC::Assessment.new @mod
    assert_equal "First Quiz", assessment.title
  end

  def test_it_converts_description
    @mod.intro = %(<h1>Hello World</h1><img src="$@FILEPHP@$$@SLASH@$folder$@SLASH@$stuff.jpg" />)
    assessment = Moodle2CC::CC::Assessment.new @mod
    assert_equal %(<h1>Hello World</h1><img src="$IMS_CC_FILEBASE$/folder/stuff.jpg" />), assessment.description
  end

  def test_it_converts_lock_at
    @mod.time_close = Time.parse("2012/12/12 12:12:12 +0000").to_i
    assessment = Moodle2CC::CC::Assessment.new @mod
    assert_equal '2012-12-12T12:12:12', assessment.lock_at
  end

  def test_it_converts_unlock_at
    @mod.time_open = Time.parse("2012/12/12 12:12:12 +0000").to_i
    assessment = Moodle2CC::CC::Assessment.new @mod
    assert_equal '2012-12-12T12:12:12', assessment.unlock_at
  end

  def test_it_converts_allowed_attempts
    @mod.attempts_number = 2
    assessment = Moodle2CC::CC::Assessment.new @mod
    assert_equal 2, assessment.allowed_attempts
  end

  def test_it_converts_scoring_policy
    @mod.grade_method = 1
    assessment = Moodle2CC::CC::Assessment.new @mod
    assert_equal 'keep_highest', assessment.scoring_policy

    @mod.grade_method = 2
    assessment = Moodle2CC::CC::Assessment.new @mod
    assert_equal 'keep_highest', assessment.scoring_policy

    @mod.grade_method = 3
    assessment = Moodle2CC::CC::Assessment.new @mod
    assert_equal 'keep_highest', assessment.scoring_policy

    @mod.grade_method = 4
    assessment = Moodle2CC::CC::Assessment.new @mod
    assert_equal 'keep_latest', assessment.scoring_policy
  end

  def test_it_converts_access_code
    @mod.password = 'password'
    assessment = Moodle2CC::CC::Assessment.new @mod
    assert_equal 'password', assessment.access_code
  end

  def test_it_converts_ip_filter
    @mod.subnet = '127.0.0.1'
    assessment = Moodle2CC::CC::Assessment.new @mod
    assert_equal '127.0.0.1', assessment.ip_filter
  end

  def test_it_converts_shuffle_answers
    @mod.shuffle_answers = true
    assessment = Moodle2CC::CC::Assessment.new @mod
    assert_equal true, assessment.shuffle_answers
  end

  def test_it_has_an_identifier
    @mod.id = 321
    assessment = Moodle2CC::CC::Assessment.new @mod
    assert_equal 'i058d7533a77712b6e7757b34e66df7fc', assessment.identifier
  end

  def test_it_has_a_non_cc_assessments_identifier
    @mod.id = 321
    assessment = Moodle2CC::CC::Assessment.new @mod
    assert_equal 'ibe158496fef4c2255274cdf9113e1daf', assessment.non_cc_assessments_identifier
  end

  def test_it_creates_resource_in_imsmanifest
    node = Builder::XmlMarkup.new
    xml = Nokogiri::XML(@assessment.create_resource_node(node))

    resource = xml.xpath('resource').first
    assert resource
    assert_equal 'associatedcontent/imscc_xmlv1p1/learning-application-resource', resource.attributes['type'].value
    assert_equal 'i058d7533a77712b6e7757b34e66df7fc/assessment_meta.xml', resource.attributes['href'].value
    assert_equal 'ibe158496fef4c2255274cdf9113e1daf', resource.attributes['identifier'].value

    file = resource.xpath('file[@href="i058d7533a77712b6e7757b34e66df7fc/assessment_meta.xml"]').first
    assert file

    file = resource.xpath('file[@href="non_cc_assessments/i058d7533a77712b6e7757b34e66df7fc.xml.qti"]').first
    assert file
  end

  def test_it_creates_assessment_meta_xml
    tmp_dir = File.expand_path('../../../tmp', __FILE__)
    @assessment.create_assessment_meta_xml(tmp_dir)
    xml = Nokogiri::XML(File.read(File.join(tmp_dir, @assessment.identifier, 'assessment_meta.xml')))

    assert xml
    assert_equal "http://canvas.instructure.com/xsd/cccv1p0 http://canvas.instructure.com/xsd/cccv1p0.xsd", xml.root.attributes['schemaLocation'].value
    assert_equal "http://www.w3.org/2001/XMLSchema-instance", xml.namespaces['xmlns:xsi']
    assert_equal "http://canvas.instructure.com/xsd/cccv1p0", xml.namespaces['xmlns']
    assert_equal @assessment.identifier, xml.xpath('xmlns:quiz').first.attributes['identifier'].value

    assert_equal 'First Quiz', xml.xpath('xmlns:quiz/xmlns:title').text
    assert_equal 'Pop quiz hot shot', xml.xpath('xmlns:quiz/xmlns:description').text
    assert_equal '2012-06-11T18:50:00', xml.xpath('xmlns:quiz/xmlns:unlock_at').text
    assert_equal '2012-06-12T18:50:00', xml.xpath('xmlns:quiz/xmlns:lock_at').text
    assert_equal '2', xml.xpath('xmlns:quiz/xmlns:allowed_attempts').text
    assert_equal 'keep_highest', xml.xpath('xmlns:quiz/xmlns:scoring_policy').text
    assert_equal 'password', xml.xpath('xmlns:quiz/xmlns:access_code').text
    assert_equal '127.0.0.1', xml.xpath('xmlns:quiz/xmlns:ip_filter').text
    assert_equal 'true', xml.xpath('xmlns:quiz/xmlns:shuffle_answers').text
  end
end
