
# these are global so can be accessed on other oabutton files
@oab_support = new API.collection {index:"oab",type:"oab_support"}
@oab_availability = new API.collection {index:"oab",type:"oab_availability"}
@oab_request = new API.collection {index:"oab",type:"oab_request",history:true}

# the normal declaration of API.service.oab is in admin.coffee, because it gets loaded before this api.coffee file

API.add 'service/oab',
  get: () ->
    return {data: 'The Open Access Button API.'}
  post:
    roleRequired:'openaccessbutton.user'
    action: () ->
      return {data: 'You are authenticated'}

_avail =
  authOptional: true
  action: () ->
    opts = if not _.isEmpty(this.request.body) then this.request.body else this.queryParams
    opts.refresh ?= this.queryParams.refresh
    opts.from ?= this.queryParams.from
    opts.plugin ?= this.queryParams.plugin
    ident = opts.doi
    ident ?= opts.url
    ident ?= 'pmid' + opts.pmid if opts.pmid
    ident ?= 'pmc' + opts.pmc.toLowerCase().replace('pmc','') if opts.pmc
    ident ?= 'TITLE:' + opts.title if opts.title
    ident ?= 'CITATION:' + opts.citation if opts.citation
    opts.url = ident
    # should maybe put auth on the ability to pass in library and libraries...
    opts.libraries = opts.libraries.split(',') if opts.libraries
    if this.user?
      opts.uid = this.userId
      opts.username = this.user.username
      opts.email = this.user.emails[0].address
    return if not opts.test and API.service.oab.blacklist(opts.url) then 400 else {data:API.service.oab.find(opts)}
API.add 'service/oab/find', get:_avail, post:_avail
API.add 'service/oab/availability', get:_avail, post:_avail # exists for legacy reasons

API.add 'service/oab/resolve',
  get: () ->
    return API.service.oab.resolve this.queryParams,undefined,this.queryParams.sources?.split(','),this.queryParams.all,this.queryParams.titles,this.queryParams.journal

API.add 'service/oab/ill/:library',
  post: () ->
    opts = this.request.body;
    opts.library = this.urlParams.library;
    return API.service.oab.ill opts

API.add 'service/oab/request',
  get:
    roleRequired:'openaccessbutton.user'
    action: () ->
      return {data: 'You have access :)'}
  post:
    authOptional: true
    action: () ->
      req = this.request.body
      req.test = if this.request.headers.host is 'dev.api.cottagelabs.com' then true else false
      return {data: API.service.oab.request(req,this.user,this.queryParams.fast)}

API.add 'service/oab/request/:rid',
  get:
    authOptional: true
    action: () ->
      if r = oab_request.get this.urlParams.rid
        r.supports = API.service.oab.supports(this.urlParams.rid,this.userId) if this.userId
        other = oab_request.find({url:r.url})
        for o in other
          r.other = o._id if o._id isnt r._id and o.type isnt r.type
        return {data: r}
      else
        return 404
  post:
    roleRequired:'openaccessbutton.user',
    action: () ->
      if r = oab_request.get this.urlParams.rid
        r = API.service.oab.own(r._id,this.user)
        n = {}
        if not r.user? and not r.story? and this.request.body.story
          n.story = this.request.body.story
          n.user = id: this.user._id, email: this.user.emails[0].address, username: (this.user.profile?.firstname ? this.user.username ? this.user.emails[0].address)
          n.user.firstname = this.user.profile?.firstname
          n.user.lastname = this.user.profile?.lastname
          n.user.affiliation = this.user.service?.openaccessbutton?.profile?.affiliation
          n.user.profession = this.user.service?.openaccessbutton?.profile?.profession
          n.count = 1 if not r.count? or r.count is 0
        if API.accounts.auth 'openaccessbutton.admin', this.user
          n.test ?= this.request.body.test
          n.status ?= this.request.body.status
          n.rating ?= this.request.body.rating
          n.name ?= this.request.body.name
          n.email ?= this.request.body.email
          n.story ?= this.request.body.story
        n.email = this.request.body.email if this.request.body.email? and ( API.accounts.auth('openaccessbutton.admin',this.user) || not r.status? || r.status is 'help' || r.status is 'moderate' || r.status is 'refused' )
        n.story = this.request.body.story if r.user? and this.userId is r.user.id and this.request.body.story?
        n.url ?= this.request.body.url
        n.title ?= this.request.body.title
        n.doi ?= this.request.body.doi
        if not n.status?
          if (not r.title and not n.title) || (not r.email and not n.email) || (not r.story and not n.story)
            n.status = 'help'
          else if r.status is 'help' and ( (r.title or n.title) and (r.email or n.email) and (r.story or n.story) )
            n.status = 'moderate'
        oab_request.update(r._id,n) if JSON.stringify(n) isnt '{}'
        return oab_request.get r._id # return how it now looks? or just return success?
      else
        return 404
  delete:
    roleRequired:'openaccessbutton.user'
    action: () ->
      r = oab_request.get this.urlParams.rid
      oab_request.remove(this.urlParams.rid) if API.accounts.auth('openaccessbutton.admin',this.user) or this.userId is r.user.id
      return {}

API.add 'service/oab/request/:rid/admin/:action',
  get:
    roleRequired:'openaccessbutton.admin'
    action: () ->
      API.service.oab.admin this.urlParams.rid,this.urlParams.action
      return {}

API.add 'service/oab/support/:rid',
  get:
    authOptional: true
    action: () ->
      return API.service.oab.support this.urlParams.rid, this.queryParams.story, this.user
  post:
    authOptional: true
    action: () ->
      return API.service.oab.support this.urlParams.rid, this.request.body.story, this.user

API.add 'service/oab/supports/:rid',
  get:
    roleRequired:'openaccessbutton.user'
    action: () ->
      return API.service.oab.supports this.urlParams.rid, this.user

API.add 'service/oab/supports',
  get: () -> return oab_support.search this.queryParams
  post: () -> return oab_support.search this.bodyParams

API.add 'service/oab/availabilities',
  get: () -> return oab_availability.search this.queryParams
  post: () -> return oab_availability.search this.bodyParams

API.add 'service/oab/requests',
  get: () -> return oab_request.search this.queryParams
  post: () -> return oab_request.search this.bodyParams

API.add 'service/oab/history',
  get: () -> return oab_request.history this.queryParams
  post: () -> return oab_request.history this.bodyParams

API.add 'service/oab/users',
  get:
    roleRequired:'openaccessbutton.admin'
    action: () -> return Users.search this.queryParams, {restrict:[{exists:{field:'roles.openaccessbutton.exact'}}]}
  post:
    roleRequired:'openaccessbutton.admin'
    action: () -> return Users.search this.bodyParams, {restrict:[{exists:{field:'roles.openaccessbutton'}}]}

API.add 'service/oab/scrape',
  get:
    #roleRequired:'openaccessbutton.user'
    action: () -> return {data:API.service.oab.scrape(this.queryParams.url,this.queryParams.content,this.queryParams.doi)}

API.add 'service/oab/redirect',
  get: () -> return API.service.oab.redirect this.queryParams.url

API.add 'service/oab/blacklist',
  get: () -> return {data:API.service.oab.blacklist(undefined,undefined,this.queryParams.stale)}

API.add 'service/oab/templates',
  get: () -> return API.service.oab.template(this.queryParams.template,this.queryParams.refresh)

API.add 'service/oab/substitute',
  post: () -> return API.service.oab.substitute this.request.body.content,this.request.body.vars,this.request.body.markdown

API.add 'service/oab/mail',
  post:
    roleRequired:'openaccessbutton.admin'
    action: () -> return API.service.oab.mail this.request.body

API.add 'service/oab/receive/:rid',
  get: () -> return if r = oab_request.find({receiver:this.urlParams.rid}) then r else 404
  post:
    authOptional: true
    action: () ->
      if r = oab_request.find {receiver:this.urlParams.rid}
        admin = this.bodyParams.admin and this.userId and API.accounts.auth('openaccessbutton.admin',this.user)
        return API.service.oab.receive this.urlParams.rid, this.request.files, this.bodyParams.url, this.bodyParams.title, this.bodyParams.description, this.bodyParams.firstname, this.bodyParams.lastname, undefined, admin
      else
        return 404

API.add 'service/oab/redeposit/:rid',
  post:
    roleRequired: 'openaccessbutton.admin'
    action: () -> return API.service.oab.redeposit this.urlParams.rid

API.add 'service/oab/receive/:rid/:holdrefuse',
  get: () ->
    if r = oab_request.find {receiver:this.urlParams.rid}
      if this.urlParams.holdrefuse is 'refuse'
        API.service.oab.refuse r._id, this.queryParams.reason
      else
        if isNaN(parseInt(this.urlParams.holdrefuse))
          return 400
        else
          API.service.oab.hold r._id, parseInt(this.urlParams.holdrefuse)
      return true
    else
      return 404

API.add 'service/oab/dnr',
  get:
    authOptional: true
    action: () ->
      return API.service.oab.dnr() if not this.queryParams.email? and this.user and API.accounts.auth 'openaccessbutton.admin', this.user
      d = {}
      d.dnr = API.service.oab.dnr this.queryParams.email
      if not d.dnr and this.queryParams.user
        u = API.accounts.retrieve this.queryParams.user
        d.dnr = 'user' if u.emails[0].address is this.queryParams.email
      if not d.dnr and this.queryParams.request
        r = oab_request.get this.queryParams.request
        d.dnr = 'creator' if r.user.email is this.queryParams.email
        if not d.dnr
          supports = oab_support.find {rid:this.queryParams.request}
          for s in supports
            d.dnr = 'supporter' if s.email is this.queryParams.email
      if not d.dnr and this.queryParams.validate
        d.validation = API.mail.validate this.queryParams.email, API.settings.service?.openaccessbutton?.mail?.pubkey
        d.dnr = 'invalid' if not d.validation.is_valid
      return d
  post: () ->
    e = this.queryParams.email ? this.request.body.email
    refuse = if this.queryParams.refuse in ['false',false] then false else true
    return if e then API.service.oab.dnr(e,true,refuse) else 400
  delete:
    authRequired: 'openaccessbutton.admin'
    action: () ->
      oab_dnr.remove({email:this.queryParams.email}) if this.queryParams.email
      return {}

API.add 'service/oab/bug',
  post: () ->
    API.mail.send {
      service: 'openaccessbutton',
      from: 'help@openaccessbutton.org',
      to: ['help@openaccessbutton.org'],
      subject: 'Feedback form submission',
      text: JSON.stringify(this.request.body,undefined,2)
    }
    return {
      statusCode: 302,
      headers: {
        'Content-Type': 'text/plain',
        'Location': (if API.settings.dev then 'https://dev.openaccessbutton.org' else 'https://openaccessbutton.org') + '/bug#defaultthanks'
      },
      body: 'Location: ' + (if API.settings.dev then 'https://dev.openaccessbutton.org' else 'https://openaccessbutton.org') + '/bug#defaultthanks'
    }

API.add 'service/oab/job',
  get:
    action: () ->
      jobs = job_job.search({service:'openaccessbutton'},{size:1000,newest:true}).hits.hits
      for j of jobs
        jobs[j] = jobs[j]._source
        jobs[j].processes = if jobs[j].processes? then jobs[j].processes.length else 0
      return jobs
  post:
    roleRequired: 'openaccessbutton.user'
    action: () ->
      processes = this.request.body.processes ? this.request.body
      for p in processes
        p.plugin = this.request.body.plugin ? 'bulk'
        p.libraries = this.request.body.libraries if this.request.body.libraries?
      return API.job.create {notify:'API.service.oab.job_complete', user:this.userId, service:'openaccessbutton', function:'API.service.oab.availability', name:(this.request.body.name ? "oab_availability"), processes:processes}

API.add 'service/oab/job/generate/:start/:end',
  post:
    roleRequired: 'openaccessbutton.admin'
    action: () ->
      start = moment(this.urlParams.start, "DDMMYYYY").valueOf()
      end = moment(this.urlParams.end, "DDMMYYYY").endOf('day').valueOf()
      processes = oab_request.find 'NOT status.exact:received AND createdAt:>' + start + ' AND createdAt:<' + end
      if processes.length
        procs = []
        procs.push({url:p.url}) for p in processes
        name = 'sys_requests_' + this.urlParams.start + '_' + this.urlParams.end
        jid = API.job.create {notify:'API.service.oab.job_complete', user:this.userId, service:'openaccessbutton', function:'API.service.oab.availability', name:name, processes:procs}
        return {job:jid, count:processes.length}
      else
        return {count:0}

API.add 'service/oab/job/:jid/progress', get: () -> return API.job.progress this.urlParams.jid

API.add 'service/oab/job/:jid/remove',
  get:
    roleRequired: 'openaccessbutton.admin'
    action: () ->
      return API.job.remove this.urlParams.jid

API.add 'service/oab/job/:jid/request',
  get:
    roleRequired: 'openaccessbutton.admin'
    action: () ->
      results = API.job.results this.urlParams.jid
      identifiers = []
      for r in results
        if r.result.availability.length is 0 and r.result.requests.length is 0
          rq = {}
          if r.result.match
            if r.result.match.indexOf('TITLE:') is 0
              rq.title = r.result.match.replace('TITLE:','')
            else if r.result.match.indexOf('CITATION:') isnt 0
              rq.url = r.result.match
          if r.result.meta and r.result.meta.article
            if r.result.meta.article.doi
              rq.doi = r.result.meta.article.doi
              rq.url ?= 'https://doi.org/' + r.result.meta.article.doi
            rq.title ?= r.result.meta.article.title
          if rq.url
            created = API.service.oab.request rq,this.userId
            identifiers.push(created) if created
      return identifiers

API.add 'service/oab/job/:jid/results', get: () -> return API.job.results this.urlParams.jid
API.add 'service/oab/job/:jid/results.json', get: () -> return API.job.results this.urlParams.jid
API.add 'service/oab/job/:jid/results.csv',
  get: () ->
    res = API.job.results this.urlParams.jid
    csv = ''
    inputs = []
    for ro in res
      for a in ro.args
        if a not in ['plugin','libraries','refresh','url','library','discovered','source'] and a not in inputs
          inputs.push a
          csv += ',' if csv isnt ''
          csv += '"' + a + '"'
    csv += ',' if csv isnt ''
    csv += '"MATCH","AVAILABLE","SOURCE","REQUEST","TITLE","DOI"'
    liborder = []
    if res[0].args.libraries?
      for l in res[0].args.libraries
        liborder.push l
        csv += ',"' + l.toUpperCase() + '"'
    for r in res
      row = r.result
      csv += '\n"'
      for i in inputs
        csv += r.args[i] if r.args[i]?
        csv += '","'
      csv += if row.match then row.match.replace('TITLE:','').replace(/"/g,'') + '","' else '","'
      av = 'No'
      for a in row.availability
        av = row.availability[a].url.replace(/"/g,'') if a.type is 'article'
      csv += av + '","'
      csv += row.meta.article.source if av isnt 'No' and row.meta?.article?.source
      csv += '","'
      rq = ''
      for re in row.requests
        if re.type is 'article'
          rq = 'https://' + (if API.settings.dev then 'dev.' else '') + 'openaccessbutton.org/request/' + row.requests[re]._id
      csv += rq + '","'
      csv += row.meta.article.title.replace(/"/g,'').replace(/[^\x00-\x7F]/g, "") if row.meta?.article?.title
      csv += '","'
      csv += row.meta.article.doi if row.meta?.article?.doi
      csv += '"'
      if row.libraries
        for lb in liborder
          lib = row.libraries[lb]
          csv += ',"'
          js = false
          if lib?.journal?.library
            js = true
            csv += 'Journal subscribed'
          rp = false
          if lib?.repository
            rp = true
            csv += '; ' if js
            csv += 'In repository'
          ll = false
          if lib?.local?.length
            ll = true
            csv += '; ' if js or rp
            csv += 'In library'
          csv += 'Not available' if not js and not rp and not ll
          csv += '"'
    job = job_job.get this.urlParams.jid
    name = if job.name then job.name.split('.')[0].replace(/ /g,'_') + '_results' else 'results'
    this.response.writeHead 200,
      'Content-disposition': "attachment; filename="+name+".csv"
      'Content-type': 'text/csv; charset=UTF-8'
      'Content-Encoding': 'UTF-8'
    this.response.end csv







API.add 'service/oab/status', get: () -> return API.service.oab.status()

