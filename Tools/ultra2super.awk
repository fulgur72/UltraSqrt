BEGIN        { ORS = "\r\n"
             }
/^[1-9]+\.$/ { s = substr("    ", 1, 6-length($0)) $0
               next
             }
/^[0-9]/     { s = s $0
               while (length(s) > 60) {
                 print substr(s,1,60)
                 s = substr(s,61,99)
               }
               next
             }
/^$/         { if (length(s) > 0) {
                 print s
                 s = ""
               }
             }
             { print
             }
            