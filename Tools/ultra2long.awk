BEGIN        { ORS = "\r\n"
               linesize = 60
               grp = 3
               sep = " "
             }
/^[1-9]+\.$/ { l = length($0)-1
	           s = substr("         ", 1, grp-(l-1)%grp-1) substr($0, 1, l)
	           d = length(s)+1
               next
             }
/^[0-9]/     { s = s $0
               while (length(s) >= linesize) {
               	 j = 1
               	 prt = ""
               	 while (j < linesize) {
               	 	if (j == d) {
               	 		prt = prt "." substr(s,j,grp)
               	 		d = 0
               	 	} else {
               	 		prt = prt sep substr(s,j,grp)
               	 	}
               	 	j += grp
               	 }
               	 if (sub("\\. ",".", prt) == 1) prt = " " prt
                 print prt
                 s = substr(s,linesize+1,999)
               }
               next
             }
/^$/         { if (length(s) > 0) {
               	 j = 1
               	 prt = ""
               	 while (j < linesize) {
               	 	if (j == d) {
               	 		prt = prt "." substr(s,j,grp)
               	 		d = 0
               	 	} else {
               	 		prt = prt sep substr(s,j,grp)
               	 	}
               	 	j += grp
               	 }
                 print prt
                 s = ""
               }
             }
             { print
             }
