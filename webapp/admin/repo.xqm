xquery version "1.0";

module namespace repomanager="http://exist-db.org/xquery/admin-interface/repo";

declare namespace package="http://expath.org/ns/pkg";
declare namespace request="http://exist-db.org/xquery/request";
declare namespace xdb="http://exist-db.org/xquery/xmldb";
declare namespace util="http://exist-db.org/xquery/util";

declare variable $repomanager:coll := "/db/system/repo";
declare variable $repomanager:repo-uri := if (request:get-parameter("repository-url", ())) then
              request:get-parameter("repository-url", ())
            else
              "http://demo.exist-db.org/exist/repo/public/all/";

declare function local:entry-data($path as xs:anyURI, $type as xs:string, $data as item()?, $param as item()*) as item()?
{

	<entry>
		<path>{$path}</path>
		<type>{$type}</type>
		<data>{$data}</data>
	</entry>
};

declare function local:entry-filter($path as xs:anyURI, $type as xs:string, $param as item()*) as xs:boolean
{
	$path = ("repo.xml", "expath-pkg.xml")
};

declare function repomanager:publicrepo() as element()
{
let $package-url := request:get-parameter("package-url", ())
return
        <div class="process">
            <h3>Actions:</h3>
            <ul>
                {
                if (ends-with($package-url,'.xar')) then
                    (<li>uploaded package: {$package-url}</li>,

                    let $http-response := httpclient:get(xs:anyURI($package-url), false(), ())
                    let $name := tokenize($package-url, "/")[last()]
                    return
                    let $package-mimetype := "application/xar",
                    $package-data := xs:base64Binary($http-response/httpclient:body/text())
                    return
                    xmldb:store($repomanager:coll, $name, $package-data, $package-mimetype)
                    )
                else
                    <li><span style="color:#FF2400">Error uploading - Must be a valid Package archive (.xar file extension)</span></li>
                }
            </ul>
                <span><i>Important: installed XQuery library mappings will not become visible until eXist is restarted.</i></span>
    </div>
};

declare function repomanager:upload() as element()
{
    let $name := request:get-parameter("name", ()),
    $repocol :=  if (collection($repomanager:coll)) then () else xmldb:create-collection('/db/system','repo'),
    $docName := if($name) then $name else request:get-uploaded-file-name("upload"),
    $file := request:get-uploaded-file-data("upload") return

        <div class="process">
            <h3>Actions:</h3>
            <ul>
                {
                if ($docName) then
                    (<li>uploaded package: {$docName}</li>,

                    xdb:decode-uri(xs:anyURI(xdb:store($repomanager:coll, xdb:encode-uri($docName), $file)))
                    )
                else
                    <li><span style="color:#FF2400">Error uploading - Must be a valid Package archive (.xar file extension)</span></li>
                }
            </ul>
    </div>
};

declare function repomanager:activate() as element()
{
    let $name := request:get-parameter("name", ())
    let $package := request:get-parameter("package", ())
    let $type := request:get-parameter("type", ())
    let $hostname := request:get-hostname()            (:  pkg-repo.jar needs http or file scheme :)
    let $port := request:get-server-port()
     return

        <div class="process">
            <h3>Actions:</h3>
            <ul>
                <li>Installed package: {$name}</li>
                {
                    repo:install(concat('http://localhost:',$port,'/exist/rest',$repomanager:coll,'/',$name,'.xar')),
                    if ($type eq "application") then
                        repo:deploy($package)
                    else
                        ()
                }
            </ul>
    </div>
};

declare function repomanager:deactivate() as element()
{
    let $name := request:get-parameter("name", ())
    let $package := request:get-parameter("package", ())
    let $type := request:get-parameter("type", ())
     return

        <div class="process">
            <h3>Actions:</h3>
            <ul>
                <li>Uninstalled package: {$name}</li>
                {
                    if ($type eq "application") then
                        repo:undeploy($package)
                    else
                        (),
                    repo:remove($package)
                }
            </ul>
                <span><i>Important: Installed XQuery libraries written in Java only become visible after a restart of eXist-db.</i></span>
    </div>
};

declare function repomanager:remove() as element()
{
    let $name := request:get-parameter("name", ())
     return

        <div class="process">
            <h3>Actions:</h3>
            <ul>
                <li>removed package: {$name}</li>
                {xmldb:remove($repomanager:coll,concat($name,'.xar'))}
            </ul>
    </div>
};

declare function repomanager:process-action() as element()*
{
    let $action := request:get-parameter("action", ()) return
        util:catch("java.lang.Exception",
            if($action eq "remove") then
            (
                repomanager:remove()
            )
            else if($action eq "activate") then
            (
                repomanager:activate()
            )
            else if($action eq "deactivate") then
            (
                repomanager:deactivate()
            )
            else if($action eq "Upload Package") then
            (
                repomanager:upload()
            )
            else if($action eq "Download from Public Repository") then
            (
                repomanager:publicrepo()
            )else(),

            <div class="error">
                An error occurred while processing the action:<br/>
                {$util:exception-message}
            </div>
        )
};

declare function repomanager:main() as element() {
    let $action := lower-case(request:get-parameter("action", "set repository"))
    let $repocol :=  if (collection($repomanager:coll)) then () else xmldb:create-collection('/db/system','repo')

    return
        <div class="panel">
        <h1>Package Repository</h1>
        <form action="?panel=repo" method="POST" enctype="multipart/form-data">
        { repomanager:process-action() }
        {
         let $files := if (collection($repomanager:coll)) then collection($repomanager:coll)/util:document-name(.)[contains(.,'.xar')] else ()
         return
            if (exists($files)) then
                <table cellspacing="0" cellpadding="5" class="browse">
                    <tr>
                        <th/>
                        <th>Name</th>
                        <th>Description</th>
                        <th>Date Installed</th>
                        <th>Status</th>
                        <th>Action</th>
                    </tr>
                    {
                        let $repos := repo:list()
                       for $file in $files
                       let $package-name := substring-before($file,'.xar')
                       let $xar := util:binary-doc(concat($repomanager:coll,'/',$file))
           
                       let $meta := compression:unzip($xar, util:function(xs:QName("local:entry-filter"), 3), (),  util:function(xs:QName("local:entry-data"), 4), ())
                       let $package := $meta//package:package
                       let $pkg-name := $package/string(@name)
                       let $pkg-abbrev := $package/string(@abbrev)
                       let $repo := $meta//repo:meta
                       let $type := $repo//repo:type/string()
           
                       let $installed := exists($repos[. eq $pkg-name])
                       return
                        <tr>
                           <td/>
                           <td><a href="{$repo//repo:website}" target="website">{$pkg-name}</a><br/>
                           {$type}</td>
                           <td>{ ( $repo//repo:description, $package/string(package:title) )[1]}</td>
           
                           <td>{xmldb:last-modified($repomanager:coll, concat($package-name,'.xar'))}</td>
                           <td> 
                           {if ($installed) then
                               <span style="color:#00FF00">Installed</span>
                           else
                               <span style="color:#FF2400">Not Installed</span>
                           }
                           </td>
                           <td>
                           {
                            if($installed) then
                                <a href="?panel=repo&amp;action=deactivate&amp;name={$package-name}&amp;package={$pkg-name}&amp;type={$type}">Uninstall</a>
                            else (
                                <a href="?panel=repo&amp;action=activate&amp;name={$package-name}&amp;package={$pkg-name}&amp;type={$type}">Install</a>,
                                <span> | </span>,
                                <a href="?panel=repo&amp;action=activate&amp;name={$package-name}">Remove</a>
                            )
                           }
           
                           </td>
                        </tr>
                   }
                </table>
            else
                ()
        }
                <span><i>Important: Installed XQuery libraries written in Java only become visible after a restart of eXist-db.</i></span>
                <br/><br/>
                <table>
                    <tr>
                        <td><input type="submit" name="action" value="Download from Public Repository"/></td>
                        <td>
                        <select size="5" width="200" style="width:340px" name="package-url">
                           {
                            let $packages := httpclient:get(xs:anyURI($repomanager:repo-uri),false(),())//httpclient:body/node()
                             return
                             for $package in $packages//package[contains(url/.,'.xar')]
                             return
                                <option value="{$package/url}">{tokenize($package/url, "/")[last()]}</option>
                           }
                        </select>
                        </td>
                    </tr>
                    <tr>
                        <td> <a href="{substring-before($repomanager:repo-uri,'all/')}" target="_repo">Public Repository URL</a> :
                        </td>
                        <td><input name="repository-url" size="40" value="{$repomanager:repo-uri}"/></td>
                        <td><input type="submit" name="action" value="set repository"/></td>
                    </tr>

                </table>
                <br/>
                <table>
                    <tr>
                        <td><input type="submit" name="action" value="Upload Package"/></td>
                        <td><input type="file" size="30" name="upload"/></td>
                    </tr>
                </table>
                <span><i>Note: You can upload example .xar packages located under webapp/repo/packages</i></span>
          </form>
        </div>
};
