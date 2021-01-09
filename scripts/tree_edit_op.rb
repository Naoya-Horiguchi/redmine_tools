require 'pp'
require 'json'

# TODO: creating new ticket who has existing tickets as children.
class TreeEditOperation
  def initialize file, renv
    @renv = renv
    @file = file
    @oldlines = {}
    @newlines = {}

    pjtreeAfter = File.read(@renv.outdir + "/pjtree.after").split("\n")
    pjtreeDiff = File.read(@renv.outdir + "/pjtree.diff").split("\n")
    @newpjs = {}
    @newparents = {}
    @oldparents = {}
    pjtreeAfter.each do |line|
      if line =~ /^(N?\d+) newpj PJ(N?\d+)/
        @newpjs[$1] = $2
      elsif line =~ /^(N?\d+) parenttask (N?\d+)/
        @newparents[$1] = $2
      end
    end
    pjtreeDiff.each do |line|
      if line =~ /^\-(N?\d+) parenttask (N?\d+)/
        @oldparents[$1] = $2
      end
    end

    File.read(@file).split("\n").each do |line|
      if line =~ /^\-(\s+)(N?\d+)\s+<([^>]+)>\s+(.+)/
        subject = $4
        relation, subject = relation_check subject
        tracker, status, progress, priority = $3.split("|")
        @oldlines[$2] = {
          :tracker => tracker,
          :status => status,
          :progress => progress.to_i,
          :priority => priority.to_i,
          :subject => subject,
        }
        if relation
          @oldlines[$2][:relation] = relation.split(",")
        else
          @oldlines[$2][:relation] = []
        end
      elsif line =~ /^\+(\s+)(N?\d+)\s+<([^>]+)>\s+(.+)/
        subject = $4
        relation, subject = relation_check subject
        tracker, status, progress, priority = $3.split("|")
        @newlines[$2] = {
          :tracker => tracker,
          :subject => subject,
        }
        @newlines[$2][:status] = status if status
        @newlines[$2][:progress] = progress.to_i if progress
        @newlines[$2][:priority] = priority.to_i if priority
        if relation
          @newlines[$2][:relation] = relation.split(",")
        else
          @newlines[$2][:relation] = []
        end
      end
    end

    olds = @oldlines.keys
    news = @newlines.keys
    @creates = news - olds
    @deletes = olds - news
    @updates = news & olds

    @creates.each do |id|
      puts "create issue #{id}"
      json = json_for_create id, @newlines[id]
      outfile = @renv.outdir + "/create.#{id}.json"
      File.write(outfile, json)
      resfile = @renv.outdir + "/create.#{id}.out.json"
      puts "__create_ticket #{outfile} > #{resfile}"
      `curl -k -s -H \"Content-Type: application/json\" -X POST --data-binary \"@#{outfile}\" -H \"X-Redmine-API-Key: #{ENV['RM_KEY']}\" #{ENV['RM_BASEURL']}/issues.json > #{resfile}`
      resjson = JSON.load(File.read(resfile))
      newid = resjson["issue"]["id"]

      addrel = @newlines[id][:relation]
      addrel.each do |rel|
        puts "CREATE_RELATION #{newid}#{rel}"
      end
    end

    @updates.each do |id|
      tmp = @oldlines[id].merge(@newlines[id])
      json = json_for_update id, tmp
      outfile = @renv.outdir + "/update.#{id}.json"
      File.write(outfile, json)
      puts "__upload_ticket #{outfile}"
      `curl -k -s -H \"Content-Type: application/json\" -X PUT --data-binary \"@#{outfile}\" -H \"X-Redmine-API-Key: #{ENV['RM_KEY']}\" #{ENV['RM_BASEURL']}/issues/#{id}.json`

      removerel = @oldlines[id][:relation] - @newlines[id][:relation]
      removerel.each do |rel|
        puts "REMOVE_RELATION #{id}#{rel}"
      end
      addrel = @newlines[id][:relation] - @oldlines[id][:relation]
      addrel.each do |rel|
        puts "CREATE_RELATION #{id}#{rel}"
      end
    end

    @deletes.each do |id|
      puts "delete issue #{id}"
    end
  end

  def relation_check str
    if str =~ /\(([\-=oc><,0-9]+)\)\s+(.+)/
      return $1, $2
    else
      return nil, str
    end
  end

  def json_for_create id, newinput
    tmp = {"issue" => {}}
    tmp["issue"]["subject"] = newinput[:subject]
    tmp["issue"]["tracker_id"] = @renv.tracker_id newinput[:tracker] if newinput[:tracker]
    tmp["issue"]["status_id"] = @renv.status_id newinput[:status] if newinput[:status]
    tmp["issue"]["done_ratio"] = newinput[:progress] if newinput[:progress]
    tmp["issue"]["priority_id"] = newinput[:priority].to_i if newinput[:priority]
    tmp["issue"]["project_id"] = @newpjs[id]
    tmp["issue"]["parent_issue_id"] = @newparents[id].nil? ? nil : @newparents[id].to_i
    tmp["issue"]["estimated_hours"] = 1
    tmp["issue"]["start_date"] = ""
    # pp JSON[tmp]
    # raise
    return JSON[tmp]
  end

  def json_for_update id, newinput
    tmp = {"issue" => {}}
    tmp["issue"]["subject"] = newinput[:subject]
    tmp["issue"]["tracker_id"] = @renv.tracker_id newinput[:tracker]
    tmp["issue"]["status_id"] = @renv.status_id newinput[:status]
    tmp["issue"]["done_ratio"] = newinput[:progress]
    tmp["issue"]["priority_id"] = newinput[:priority].to_i
    tmp["issue"]["project_id"] = @newpjs[id].to_i
    tmp["issue"]["parent_issue_id"] = @newparents[id].nil? ? nil : @newparents[id].to_i
    # pp JSON[tmp]
    # raise
    return JSON[tmp]
  end

  def find_new_parent id
  end

  def find_new_project id
  end
end

class RedmineEnv
  attr_accessor :outdir

  def initialize
    @rm_config = ENV['RM_CONFIG']
    @projects = JSON.load(File.read(@rm_config + "/projects.json"))
    @trackers = JSON.load(File.read(@rm_config + "/trackers.json"))
    @statuses = JSON.load(File.read(@rm_config + "/issue_statuses.json"))
    @priorities = JSON.load(File.read(@rm_config + "/priorities.json"))
    @users = JSON.load(File.read(@rm_config + "/users.json"))
    @outdir = ENV['RM_OUTDIR']
    raise "Environment variable RM_OUTDIR not set." if @outdir.nil?
    raise "outdir #{@outdir} is not exist." if ! File.directory?(@outdir)
  end

  def status_id status
    tmpreg = Regexp.new(Regexp.escape(status), Regexp::IGNORECASE)
    tmp = @statuses["issue_statuses"].select {|e| e["name"] =~ tmpreg}
    if tmp.nil? or tmp.empty?
      raise "no status id found for #{status}"
    else
      return tmp[0]["id"]
    end
  end

  def tracker_id tracker
    tmpreg = Regexp.new(Regexp.escape(tracker), Regexp::IGNORECASE)
    tmp = @trackers["trackers"].select {|e| e["name"] =~ tmpreg}
    if tmp.nil?
      raise "no tracker id not found for #{tracker}"
    else
      return tmp[0]["id"]
    end
  end
end

if $0 == __FILE__
  renv = RedmineEnv.new
  teo = TreeEditOperation.new ARGV[0], renv
end
