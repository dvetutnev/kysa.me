{ lib }:

siteUrl:
let
  siteUrl' = if lib.strings.hasSuffix "/" siteUrl then siteUrl else "${siteUrl}/";
  mkNavLink = { urn, name }: ''<li><a href="${siteUrl'}${urn}">${name}</a></li>'';

  navLinks = lib.strings.concatStrings (
    map mkNavLink [
      {
        urn = "README.html";
        name = "Home";
      }
      {
        urn = "pages/about.html";
        name = "About";
      }
    ]
  );

  mkSideBar = navLinks: ''
    <div class="sidebar">
      <div class="container sidebar-sticky">
        <div class="sidebar-about">
          <a href="${siteUrl'}"><h1>kysa.me</h1></a>
            <p class="lead">&Zcy;&acy;&mcy;&iecy;&tcy;&ocy;&chcy;&kcy;&icy;</p>
        </div>

        <ul class="sidebar-nav">
          ${navLinks}
        </ul>

        <p>&copy; 2017. All rights reserved.</p>
      </div>
    </div>'';
in
mkSideBar navLinks
