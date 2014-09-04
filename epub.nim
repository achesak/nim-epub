# Nimrod module for working with EPUB files.
# nimrod-epub currently only supports EPUB 3.x.

# Written by Adam Chesak.
# Released under the MIT open source license.


# Import the modules.
import strutils
import xmlparser
import xmltree
import streams


## Represents an ``identifier`` element.
type EPUBIdentifier* = tuple[id : string, value : string]

## Represents a ``title`` element.
type EPUBTitle* = tuple[id : string, lang : string, dir : string, value : string]

## Represents a ``language`` element.
type EPUBLanguage* = tuple[id : string, value : string]

## Represents a ``contributor`` element.
type EPUBContributor* = tuple[id : string, lang : string, dir : string, value : string]

## Represents a ``creator`` element.
type EPUBCreator* = tuple[id : string, lang : string, dir : string, value : string]

## Represents a ``source`` element.
type EPUBSource* = tuple[id : string, value : string]

## Represents a ``type`` element.
type EPUBType* = tuple[id : string, value : string]

## Represents a ``description`` element.
type EPUBDescription* = tuple[id : string, lang : string, dir : string, value : string]

## Represents a ``format`` element.
type EPUBFormat* = tuple[id : string, value : string]

## Represents a ``publisher`` element.
type EPUBPublisher* = tuple[id : string, lang : string, dir : string, value : string]

## Represents a ``relation`` element.
type EPUBRelation* = tuple[id : string, lang : string, dir : string, value : string]

## Represents a ``rights`` element.
type EPUBRights* = tuple[id : string, lang : string, dir : string, value : string]

## Represents a ``subject`` element.
type EPUBSubject* = tuple[id : string, lang : string, dir : string, value : string]

## Represents a ``coverage`` element.
type EPUBCoverage* = tuple[id : string, lang : string, dir : string, value : string]

## Represents a ``meta`` element.
type EPUBMeta* = tuple[property : string, refines : string, id : string, scheme : string, value : string]

## Represents a ``link`` element.
type EPUBLink* = tuple[href : string, rel : string, id : string, refines : string, mediaType : string]

## Represents a ``metadata`` element.
type EPUBMetadata* = tuple[identifiers : seq[EPUBIdentifier], titles : seq[EPUBTitle], languages : seq[EPUBLanguage], contributors :
                            seq[EPUBContributor], creators : seq[EPUBCreator], date : string, source : EPUBSource, epubType : EPUBType,
                            metas : seq[EPUBMeta], description : EPUBDescription, format : EPUBFormat, publisher : EPUBPublisher,
                            relation : EPUBRelation, rights : EPUBRights, subject : EPUBSubject, coverage : EPUBCoverage, links : seq[EPUBLink]]

## Represents an ``item`` element.
type EPUBItem* = tuple[id : string, href : string, mediaType : string, fallback : string, properties : string, mediaOverlay : string]

## Represents a ``manifest`` element.
type EPUBManifest* = tuple[id : string, items : seq[EPUBItem]]

## Represents an ``itemref`` element.
type EPUBItemref* = tuple[idref : string, linear : string, id : string, properties : string]

## Represents a ``spine`` element.
type EPUBSpine* = tuple[id : string, toc : string, pageProgressionDirection : string, itemrefs : seq[EPUBItemref]]

## Represents a ``mediaType`` element.
type EPUBMediaType* = tuple[mediaType : string, handler : string]

## Represents a ``bindings`` element.
type EPUBBindings* = tuple[mediaTypes : seq[EPUBMediaType]]

## Represents the package document.
type EPUBPackage* = tuple[version : string, uniqueIdentifier : string, lang : string, dir : string, id : string, metadata : EPUBMetadata,
                           manifest : EPUBManifest, spine : EPUBSpine, bindings : EPUBBindings]

## Represents a ``rootfile`` element.
type EPUBRootFile* = tuple[fullPath : string, mediaType : string]


# It looks like despite having a proc in the zipfiles module it isn't actually possible to
# use extractFile() to extract files. Might write a wrapper around something later.
# 
#proc unpackEPUB*(filename : string, destination : string): bool =
#    ## Unpacks the EPUB file, and returns success or failure.
#
#    var archive : TZipArchive
#    var state : bool = archive.open(filename, fmRead)
#    if not state:
#        return false
#    for i in walkFiles(archive):
#        archive.extractFile(i, destination & i)
#    return true


proc getPackageDocument*(filename : string): string = 
    ## Gets the location of the package document. ``filename`` is the location of the EPUB directory.
    ## Returns an empty string if no valid package document was found.
    
    var container : string = filename & "/META-INF/container.xml"
    var base : PXmlNode = loadXML(container)
    var rootfiles : seq[PXmlNode] = base.child("rootfiles").findAll("rootfile")
    
    for i in rootfiles:
        if i.attr("media-type") == "application/oebps-package+xml":
            return filename & "/" & i.attr("full-path")
    
    return ""


proc parseContainer*(filename : string): seq[EPUBRootFile] =
    ## Returns a sequence representing the ``rootfile`` elements in the container document. ``filename``
    ## is the location of the EPUB directory.
    
    var container : string = filename & "/META-INF/container.xml"
    var base : PXmlNode = loadXML(container)
    var rootfiles : seq[PXmlNode] = base.child("rootfiles").findAll("rootfile")
    
    var rf = newSeq[EPUBRootFile](len(rootfiles))
    for i in 0..high(rootfiles):
        var r : EPUBRootFile
        r.fullPath = rootfiles[i].attr("full-path")
        r.mediaType = rootfiles[i].attr("media-type")
        rf[i] = r
    
    return rf


proc parsePackageDocument*(filename : string): EPUBPackage = 
    ## Parses the package document. ``filename`` is the location of the EPUB directory.
    
    var epub : EPUBPackage
    var path : string = getPackageDocument(filename)
    if path == "":
        return epub
    var base : PXmlNode = loadXML(path)
    
    epub.version = base.attr("version")
    epub.uniqueIdentifier = base.attr("unique-identifier")
    epub.lang = base.attr("xml:lang")
    epub.dir = base.attr("dir")
    epub.id = base.attr("id")
    
    var md : EPUBMetaData
    var mdElem = base.child("metadata")
    
    var id : seq[PXmlNode] = mdElem.findAll("dc:identifier")
    var idSeq = newSeq[EPUBIdentifier](len(id))
    for i in 0..high(id):
        var ide : EPUBIdentifier
        ide.id = id[i].attr("id")
        ide.value = id[i].innerText
        idSeq[i] = ide
    md.identifiers = idSeq
    
    var ti : seq[PXmlNode] = mdElem.findAll("dc:title")
    var tiSeq = newSeq[EPUBTitle](len(ti))
    for i in 0..high(ti):
        var tie : EPUBTitle
        tie.id = ti[i].attr("id")
        tie.lang = ti[i].attr("xml:lang")
        tie.dir = ti[i].attr("dir")
        tie.value = ti[i].innerText
        tiSeq[i] = tie
    md.titles = tiSeq
    
    var la : seq[PXmlNode] = mdElem.findAll("dc:language")
    var laSeq = newSeq[EPUBLanguage](len(la))
    for i in 0..high(la):
        var lae : EPUBLanguage
        lae.id = la[i].attr("id")
        lae.value = la[i].innerText
        laSeq[i] = lae
    md.languages = laSeq
    
    var co : seq[PXmlNode] = mdElem.findAll("dc:contributor")
    var coSeq = newSeq[EPUBContributor](len(co))
    for i in 0..high(co):
        var coe : EPUBContributor
        coe.id = co[i].attr("id")
        coe.lang = co[i].attr("xml:lang")
        coe.dir = co[i].attr("dir")
        coe.value = co[i].innerText
        coSeq[i] = coe
    md.contributors = coSeq
    
    var cr : seq[PXmlNode] = mdElem.findAll("dc:creator")
    var crSeq = newSeq[EPUBCreator](len(cr))
    for i in 0..high(cr):
        var cre : EPUBCreator
        cre.id = cr[i].attr("id")
        cre.lang = cr[i].attr("xml:lang")
        cre.dir = cr[i].attr("dir")
        cre.value = cr[i].innerText
        crSeq[i] = cre
    md.creators = crSeq
    
    if mdElem.child("dc:date") != nil:
        md.date = mdElem.child("dc:date").innerText
    
    if mdElem.child("dc:source") != nil:
        var so : EPUBSource
        so.id = mdElem.child("dc:source").attr("id")
        so.value = mdElem.child("dc:source").innerText
        md.source = so
    
    if mdElem.child("dc:type") != nil:
        var ty : EPUBType
        ty.id = mdElem.child("dc:type").attr("id")
        ty.value = mdElem.child("dc:type").innerText
        md.epubType = ty
    
    var me : seq[PXmlNode] = mdELem.findAll("meta")
    var meSeq = newSeq[EPUBMeta](len(me))
    for i in 0..high(me):
        var mee : EPUBMeta
        mee.value = me[i].innerText
        mee.property = me[i].attr("property")
        mee.refines = me[i].attr("refines")
        mee.id = me[i].attr("id")
        mee.scheme = me[i].attr("scheme")
        meSeq[i] = mee
    md.metas = meSeq
    
    if mdElem.child("dc:description") != nil:
        var desc : PXmlNode = mdElem.child("dc:description")
        var de : EPUBDescription
        de.id = desc.attr("id")
        de.lang = desc.attr("xml:lang")
        de.dir = desc.attr("dir")
        de.value = desc.innerText
        md.description = de
    
    if mdElem.child("dc:format") != nil:
        var fo : EPUBFormat
        fo.id = mdElem.child("dc:format").attr("id")
        fo.value = mdElem.child("dc:format").innerText
        md.format = fo
    
    if mdElem.child("dc:publisher") != nil:
        var pub : PXmlNode = mdElem.child("dc:publisher")
        var pu : EPUBPublisher
        pu.id = pub.attr("id")
        pu.lang = pub.attr("xml:lang")
        pu.dir = pub.attr("dir")
        pu.value = pub.innerText
        md.publisher = pu
    
    if mdElem.child("dc:relation") != nil:
        var rel : PXmlNode = mdElem.child("dc:relation")
        var re : EPUBRelation
        re.id = rel.attr("id")
        re.lang = rel.attr("xml:lang")
        re.dir = rel.attr("dir")
        re.value = rel.innerText
        md.relation = re
    
    if mdElem.child("dc:rights") != nil:
        var rig : PXmlNode = mdElem.child("dc:rights")
        var ri : EPUBRights
        ri.id = rig.attr("id")
        ri.lang = rig.attr("xml:lang")
        ri.dir = rig.attr("dir")
        ri.value = rig.innerText
        md.rights = ri
    
    if mdElem.child("dc:subject") != nil:
        var sub : PXmlNode = mdElem.child("dc:subject")
        var su : EPUBSubject
        su.id = sub.attr("id")
        su.lang = sub.attr("xml:lang")
        su.dir = sub.attr("dir")
        su.value = sub.innerText
        md.subject = su
    
    if mdElem.child("dc:coverage") != nil:
        var cov : PXmlNode = mdElem.child("dc:coverage")
        var cv : EPUBCoverage
        cv.id = cov.attr("id")
        cv.lang = cov.attr("xml:lang")
        cv.dir = cov.attr("dir")
        cv.value = cov.innerText
        md.coverage = cv
    
    var li : seq[PXmlNode] = mdELem.findAll("link")
    var liSeq = newSeq[EPUBLink](len(li))
    for i in 0..high(li):
        var lie : EPUBLink
        lie.href = li[i].attr("href")
        lie.refines = li[i].attr("refines")
        lie.id = li[i].attr("id")
        lie.rel = li[i].attr("rel")
        lie.mediaType = li[i].attr("media-type")
        liSeq[i] = lie
    md.links = liSeq
    
    epub.metadata = md
    
    var mn : EPUBManifest
    var mnElem : PXmlNode = base.child("manifest")
    mn.id = mnElem.attr("id")
    
    var im : seq[PXmlNode] = mnElem.findAll("item")
    var imSeq = newSeq[EPUBItem](len(im))
    for i in 0..high(im):
        var ime : EPUBItem
        ime.id = im[i].attr("id")
        ime.href = im[i].attr("href")
        ime.mediaType = im[i].attr("media-type")
        ime.fallback = im[i].attr("fallback")
        ime.properties = im[i].attr("properties")
        ime.mediaOverlay = im[i].attr("media-overlay")
        imSeq[i] = ime
    mn.items = imSeq
    
    epub.manifest = mn
    
    var sp : EPUBSpine
    var spElem : PXmlNode = base.child("spine")
    sp.id = spElem.attr("id")
    sp.toc = spElem.attr("toc")
    sp.pageProgressionDirection = spElem.attr("page-progression-direction")
    
    var ir : seq[PXmlNode] = spElem.findAll("itemref")
    var irSeq = newSeq[EPUBItemref](len(ir))
    for i in 0..high(ir):
        var ire : EPUBItemref
        ire.idref = ir[i].attr("idref")
        ire.linear = ir[i].attr("linear")
        ire.id = ir[i].attr("id")
        ire.properties = ir[i].attr("properties")
        irSeq[i] = ire
    sp.itemrefs = irSeq
    
    epub.spine = sp
    
    if base.child("bindings") != nil:
        var bi : EPUBBindings
        var biElem : PXmlNode = base.child("bindings")
        
        var mt : seq[PXmlNode] = biElem.findAll("mediaType")
        var mtSeq = newSeq[EPUBMediaType](len(mt))
        for i in 0..high(mt):
            var mte : EPUBMediaType
            mte.mediaType = mt[i].attr("media-type")
            mte.handler = mt[i].attr("handler")
            mtSeq[i] = mte
        bi.mediaTypes = mtSeq
        
        epub.bindings = bi
    
    return epub
