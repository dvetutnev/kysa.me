{ lib }:

{ siteUrl, navigation }:
let
  mkNavEntry = { urn, name }: ''<li><a href="${siteUrl}${urn}">${name}</a></li>'';

  navLinks = lib.strings.concatStrings (map mkNavEntry navigation);

  mkSideBar = navLinks: ''
    <div class="sidebar">
      <div class="container sidebar-sticky">
        <div class="sidebar-about">
          <a href="${siteUrl}"><h1>kysa.me</h1></a>
            <p class="lead">&Zcy;&acy;&mcy;&iecy;&tcy;&ocy;&chcy;&kcy;&icy;</p>
        </div>

        <ul class="sidebar-nav">
          ${navLinks}
        </ul>

        <p>&copy; 2025. All rights reserved.</p>
      </div>
    </div>'';
in
mkSideBar navLinks
