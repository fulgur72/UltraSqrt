BEGIN        {  RS = "\r?\n"
               ORS = "\r\n"
               linesize = 60
               grp = 3
               sep = " "
             }
/^[0-9]+\.$/ { d = length($0)
               s = substr($0, 1, d-1)
               while (d % grp != 1) {
                 d ++
                 s = sep s
               }
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
                 print prt
                 s = substr(s,linesize+1,999)
               }
               next
             }
END          { if (length(s) > 0) {
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
/^[^*]/      { print
               print ""
             }
