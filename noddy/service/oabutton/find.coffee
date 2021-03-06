
###
{
  availability: [
    {
      type: 'article',
      url: <URL TO OBJECT - PROB A REDIRECT URL VIA OUR SYSTEM FOR STAT COUNT>
    }
  ],
  # will only list requests of types that are not yet available
  requests:[
    {
      type:'data',
      _id: 1234567890,
      usupport: true/false,
      ucreated: true/false
    },
    ...
  ]
}
###
API.service.oab.find = (opts={url:undefined,type:undefined}) ->
  console.log opts.refresh
  opts.refresh ?= 30 # default refresh. If true then we won't even use successful previous lookups, otherwise if number only use failed lookups within refresh days
  if typeof opts.refresh isnt 'number'
    try
      n = parseInt opts.refresh
      opts.refresh = if isNaN(n) then 0 else n
    catch
      opts.refresh = 0
  if opts.url
    if opts.url.indexOf('10.1') is 0
      opts.doi = opts.url
      opts.url = 'https://doi.org/' + opts.url
    else if opts.url.toLowerCase().indexOf('pmc') is 0
      opts.url = 'http://europepmc.org/articles/PMC' + opts.url.toLowerCase().replace('pmc','')
    else if opts.url.length < 10 and opts.url.indexOf('.') is -1 and not isNaN(parseInt(opts.url))
      opts.url = 'https://www.ncbi.nlm.nih.gov/pubmed/' + opts.url
  if not opts.url
    opts.url = 'CITATION:'+opts.citation if opts.citation
    opts.url = 'TITLE:'+opts.title if opts.title
    opts.url = 'https://www.ncbi.nlm.nih.gov/pubmed/' + opts.pmid if opts.pmid
    opts.url = 'http://europepmc.org/articles/PMC' + opts.pmc.toLowerCase().replace('pmc','') if opts.pmc
    opts.url = 'http://europepmc.org/articles/PMC' + opts.pmcid.toLowerCase().replace('pmc','') if opts.pmcid
    opts.url = 'https://doi.org/' + (if opts.doi.indexOf('doi.org/') isnt -1 then opts.doi.split('doi.org/')[1] else opts.doi) if opts.doi
  return {} if not opts.url?

  ret = {match:opts.url,availability:[],requests:[],meta:{article:{},data:{}}}
  ret.library = API.service.oab.library(opts) if opts.library
  ret.libraries = API.service.oab.libraries(opts) if opts.libraries
  already = []

  opts.discovered = {article:false,data:false}
  opts.source = {article:false,data:false}
  if opts.type is 'article' or not opts.type?
    if opts.refresh isnt 0 and opts.url
      avail = oab_availability.find {'url':opts.url,'discovered':{exists:{field:'discovered.article'}}}
      if avail?.discovered?.article and ret.meta.article.redirect = API.service.oab.redirect(avail.discovered.article) isnt false
        ret.meta.article.url = avail.discovered.article
        ret.meta.article.source = avail.source?.article
        ret.meta.cache = true
        ret.meta.refresh = opts.refresh # if we have a discovered article that is not since blacklisted we always reuse it - this is just for info
    d = new Date()
    if not ret.meta.article.url and (opts.refresh is 0 or not oab_availability.find 'url.exact:"'+opts.url + '" AND createdAt:>' + d.setDate(d.getDate() - opts.refresh) )
      ret.meta.article = API.service.oab.resolve opts.url, opts.dom, ['oabutton','eupmc','oadoi','share','core','openaire','figshare','doaj']
      ret.match = 'https://doi.org/' + ret.meta.article.doi if ret.meta.article.doi and ret.match.indexOf('http') isnt 0
    if ret.meta.article.url and ret.meta.article.source and ret.meta.article.redirect isnt false and not ret.meta.article.journal_url
      opts.source.article = ret.meta.article.source
      opts.discovered.article = if typeof ret.meta.article.redirect is 'string' then ret.meta.article.redirect else ret.meta.article.url
      ret.availability.push {type:'article',url:opts.discovered.article}
      already.push 'article'

  opts.url = 'https://doi.org/' + ret.meta.article.doi if opts.url.indexOf('http') isnt 0 and ret.meta.article.doi
  # so far we are only doing availability checks for articles, so only need to check requests for data types or articles that were not found yet
  if (opts.type isnt 'article' or 'article' not in already) and requests = oab_request.find {url:opts.url,type:opts.type}
    for r in requests
      if r.type not in already
        rq =
          type: r.type
          _id: r._id
        rq.ucreated = if opts.uid and r.user?.id is opts.uid then true else false
        rq.usupport = if opts.uid then API.service.oab.supports(r._id, opts.uid)? else false
        ret.requests.push rq
        already.push r.type

  delete opts.dom
  oab_availability.insert(opts) if not opts.nosave # save even if was a cache hit, to track usage of the endpoint
  return ret


