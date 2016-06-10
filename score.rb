require 'nokogiri'

class Score
  attr_reader :score_list, :gpas

  def initialize
    @score_file = "credit_score.html"
    @guide_score_file = "guide_score.html"
    get_score
    get_GPA
  end

  private
    def get_GPA (only_required = true)
      @gpas = []
      @score_list.each do |s|
        sum_point = 0
        sum_credit = 0
        s.each do |c|
          if ((c[:prop] != "选修") || !only_required)
            sum_point += c[:point].to_f * c[:credit].to_f
            sum_credit += c[:credit].to_f
          end
        end
        @gpas << {
          credit: sum_credit,
          gpa: (sum_point / sum_credit).round(3)
        }
      end
    end

    def get_point (grade)
      #如果只包含了数字和小数点
      if grade.match(/[^\d\.]+/).nil?
        s = grade.to_i
        case s
        when 0...60
          0
        when 60..90
          ((s-60) / 5) * 0.5 + 2.0
        when 90..100
          5
        else
          9999999
        end
      else  #改版后基本用不到下面了
        case grade
        when "优秀"
          5
        when "良好"
          4
        when "中等"
          3
        when "及格"
          2
        else
          0
        end
      end
    end

    def get_score
      @guide_score_list = []
      page = Nokogiri::HTML(open(@guide_score_file).read,nil,"gbk")
      subjects = page.css("tr.odd")
      subjects.each do |m|
        next if m.children[9].nil? || m.children[9].text.strip.length != 8
        subject = {}
        subject[:cno] = m.children[1].text.slice(1..-1).strip
        subject[:name] = m.children[3].text.slice(1..-1).strip
        subject[:grade] = m.children[7].text.slice(1..-1).strip
        subject[:date] = m.children[9].text.slice(1..-1).strip
        subject[:point] = get_point(subject[:grade]).to_s
        @guide_score_list << subject
      end
      parser_credit # 获取学分列表
      merge_by_name # 根据课程名称进行合并
      nest_with_date  # 按照学期存到数组
    end

    def parser_credit
      @credit_list = []
      page = Nokogiri::HTML(open(@score_file).read,nil,"gbk")
      subjects = page.css("tr.odd")
      subjects.each do |m|
        subject = {}
        subject[:name] = m.children[5].text.strip
        subject[:eng_name] = m.children[7].text.strip
        subject[:credit] = m.children[9].text.strip
        subject[:prop] = m.children[11].text.strip
        @credit_list << subject
      end
    end

    def merge_by_name
      @guide_score_list.each do |g|
        @credit_list.each do |s|
          # 如果课程名相同则合并这两个Hash
          g.merge!(s) if g[:name] == s[:name]
        end
      end
    end

    def nest_with_date
      @score_list = []
      res = []
      z = 0
      length = @guide_score_list.length
      @guide_score_list.each_with_index do |s, i|
        z += 1
        # TODO: 此处应该有容错，保证在一个学期内就可以，不必相等
        if s[:date] != @guide_score_list[(i+1) % length][:date]
          res << z
        end
      end
      res.length.times do |i|
        # 按照考试时间将其分为二维数组
        @score_list << @guide_score_list.slice((i == 0 ? 0 : res[i-1])...res[i])
      end
    end

end
