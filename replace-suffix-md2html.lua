return {
   Link = function(link)
      if not string.find(link.target, "^https?://") then
	 link.target = string.gsub(link.target, ".md$", ".html")
      end
      return link
   end,
}
