BEGIN        { ORS = "\r\n"
               linesize = 60
             }
/^[1-9]+\.$/ { s = substr("    ", 1, 6-length($0)) $0
               next
             }
/^[0-9]/     { s = s $0
               while (length(s) >= linesize) {
                 print substr(s,1,linesize)
                 s = substr(s,linesize+1,999)
               }
               next
             }
END          { if (length(s) > 0) {
                 print s
                 s = ""
               }
             }
             { print
             }
