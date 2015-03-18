# Introduction #

TiVo Butler downloads the Now Playing list from your devices by asking the TiVo to return it's contents as XML.  If you run into any issues with how things are displaying or listed, then it may be useful to download the XML to see what TiVo Butler is getting and see if the issue is with the data or with TiVo Butler mis-reading something.

If you submit an issue and need to include the XML content, you can probably cut out everything except the information pertaining to the program that demonstrates your issue.  Everything inside of the Item tags should be returned.

# Details #

## Command Line method ##
Use this command from Terminal.app to save the Now Playing list from your tivo.  Replace 0.0.0.0 with the IP of your TiVo and 12345678 with your MAK

`curl --insecure --digest --user tivo:12345678 "https://0.0.0.0/TiVoConnect?Command=QueryContainer&Container=%2FNowPlaying&Recurse=Yes&AnchorOffset=0" | tidy -xml -indent > TiVo_NowPlaying.xml`
`

## Web Browser method ##
You can also do this via your browser, using this address (again, replace 0.0.0.0 with the IP of your TiVo

`https://0.0.0.0/TiVoConnect?Command=QueryContainer&Container=%2FNowPlaying&Recurse=Yes&AnchorOffset=0`

You will be asked to authenticate.  Use "tivo" as the username and your MAK as the password.  From the text that is returned, you can control-click and choose "View Source" to see the original XML.  It won't be very readable, but it will be the same logical content as what is produced from the above command line.