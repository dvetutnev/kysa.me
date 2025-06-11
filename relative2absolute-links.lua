return {
   Link = function(link)
      if not string.find(link.target, "^https?://") then
	 html_link = string.gsub(link.target, ".md$", ".html")
	 link.target = string.format("%s%s", os.getenv("SITE_URL"), html_link)
      end
      return link
   end,

   Image = function(image)
      if not string.find(image.src, "^https?://") then
	 image.src = string.format("%s%s", os.getenv("SITE_URL"), image.src)
      end
      return image
   end,
}
