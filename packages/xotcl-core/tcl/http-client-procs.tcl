ad_library {
  
  XOTcl implementation for synchronous and asynchronous 
  HTTP and HTTPS requests

  @author Gustaf Neumann, Stefan Sobernig
  @creation-date 2007-10-05
  @cvs-id $Id: http-client-procs.tcl,v 1.7.2.5 2008/11/21 23:20:23 gustafn Exp $
}

namespace eval ::xo {
  #
  # Defined classes
  #  1) HttpCore (common base class)
  #  2) HttpRequest (for blocking requests + timeout support)
  #  3) AsyncHttpRequest (for non-blocking requests + timeout support)
  #  4) HttpRequestTrace (mixin class)
  #  5) Tls (mixin class, applicable to various protocols)
  #
  ######################
  #
  # 1 HttpRequest
  #
  # HttpRequest is a class to implement the client side
  # for the HTTP methods GET and POST.
  #
  # Example of a GET request:
  #
  #  set r [::xo::HttpRequest new -url http://www.openacs.org/]
  #
  # The resulting object $r contains all information
  # about the requests, such as e.g. status_code or 
  # data (the response body from the server). For details
  # look into the output of [$r serialize]. The result 
  # object in $r is automatically deleted at cleanup of
  # a connection thread.
  #
  # Example of a POST request with a form with var1 and var2
  # (providing post_data causes the POST request).
  #    
  #  set r [::xo::HttpRequest new \
  #             -url http://yourhost.yourdomain/yourpath \
  #             -post_data [export_vars {var1 var2}] \
  #             -content_type application/x-www-form-urlencoded]
  #
  # More recently, we added timeout support for blocking http
  # requests. By passing a timeout parameter, you gain control
  # on the total roundtrip time (in milliseconds, ms):
  #
  #  set r [::xo::HttpRequest new \
  #  		-url http://www.openacs.org/ \
  #  		-timeout 1500]
  #
  # Please, make sure that you use a recent distribution of tclthread
  # ( > 2.6.5 ) to have the blocking-timeout feature working
  # safely. This newly introduced feature makes use of advanced thread
  # synchronisation offered by tclthread that needed to be fixed in
  # tclthread <= 2.6.5. At the time of this writing, there was no
  # post-2.6.5 release of tclthread, hence, you are required to obtain a
  # CVS snapshot, dating at least 2008-05-23. E.g.:
  # 
  # cvs -z3 -d:pserver:anonymous@tcl.cvs.sourceforge.net:/cvsroot/tcl co \
  #		 -D 20080523 -d thread2.6.5~20080523 thread
  #
  # Provided that the Tcl module tls (see e.g. http://tls.sourceforge.net/)
  # is available and can be loaded via "package require tls" into 
  # the aolserver, you can use both TLS/SSL secured or unsecured requests 
  # in the synchronous/ asynchronous mode by using an
  # https url.
  # 
  #  set r [::xo::HttpRequest new -url https://learn.wu-wien.ac.at/]
  #
  ######################
  #
  # 2 AsyncHttpRequest
  #
  # AsyncHttpRequest is a subclass for HttpCore implementing
  # asynchronous HTTP requests without vwait (vwait causes 
  # stalls on aolserver). AsyncHttpRequest requires to provide a listener 
  # or callback object that will be notified upon success or failure of 
  # the request.
  #
  # Asynchronous requests are much more complex to handle, since
  # an application (a connection thread) can submit multiple
  # asynchronous requests in parallel, which are likely to
  # finish after the current request is done. The advantages
  # are that the spooling of data can be delegated to a spooling
  # thead and the connection thread is available for handling more
  # incoming connections. The disadvantage is the higher
  # complexity, one needs means to collect the received data.
  #
  # The following example uses the background delivery thread for
  # spooling and defines in this thread a listener object (a). 
  # Then in the second step, the listener object is used in te
  # asynchronous request (b).
  #
  # (a) Create a listener/callback object in the background. Provide
  # the two needed methods, one being invoked upon success (deliver),
  # the other upon failure or cancellation (done).
  #
  #  ::bgdelivery do Object ::listener \
  #     -proc start_request {payload obj} {
  #       my log "request $obj started"
  #     } -proc request_data {payload obj} {
  #       my log "partial or complete post"
  #     } -proc start_reply {payload obj} {
  #       my log "reply $obj started"
  #     } -proc reply_data {payload obj} {
  #       my log "partial or complete delivery"
  #     } -proc success {data obj} {
  #       my log "Asynchronous request successfully completed"
  #     } -proc failure {reason obj} {
  #       my log "Asynchronous request failed: $reason"
  #     }
  #
  # (b)  Create the actual asynchronous request object in the background. 
  # Make sure that you specify the previously created listener/callback 
  # object as "request_manager" to the request object.
  #
  #  ::bgdelivery do ::xo::AsyncHttpRequest new \
  #     -url "https://oacs-dotlrn-conf2007.wu-wien.ac.at/conf2007/" \
  #     -request_manager ::listener
  #
  ######################
  #
  # 3 HttpRequestTrace
  #
  # HttpRequestTrace can be used to trace one or all requests.
  # If activated, the class writes protocol data into 
  # /tmp/req-<somenumber>.
  #
  # Use 
  #
  #  ::xo::HttpCore instmixin add ::xo::HttpRequestTrace
  #
  # to activate trace for all requests, 
  # or mixin the class into a single request to trace it.
  #

  Class create HttpCore \
      -slots {
        Attribute host
        Attribute protocol -default "http" 
        Attribute port 
        Attribute path -default "/"
        Attribute url
        Attribute post_data -default ""
        Attribute content_type -default "text/plain"
        Attribute request_header_fields -default {}
        Attribute user_agent -default "xohttp/0.2"
      }

  # Provide for mapping from HTTP charset encoding labels
  # to Tcl-specific ones (see http://naviserver.cvs.sourceforge.net/naviserver/naviserver/nsd/encoding.c?view=markup)

  HttpCore array set http_to_tcl_encodings {
    iso-2022-jp     	iso2022-jp
    iso-2022-kr   	iso2022-kr
    iso-8859-1         	iso8859-1
    iso-8859-2         	iso8859-2
    iso-8859-3         	iso8859-3
    iso-8859-4         	iso8859-4
    iso-8859-5         	iso8859-5
    iso-8859-6         	iso8859-6
    iso-8859-7         	iso8859-7
    iso-8859-8         	iso8859-8
    iso-8859-9         	iso8859-9
    korean             	ksc5601
    ksc_5601           	ksc5601
    mac                	macRoman
    mac-centeuro       	macCentEuro
    mac-centraleupore  	macCentEuro
    mac-croatian       	macCroatian
    mac-cyrillic       	macCyrillic
    mac-greek          	macGreek
    mac-iceland        	macIceland
    mac-japan          	macJapan
    mac-roman          	macRoman
    mac-romania        	macRomania
    mac-thai            macThai
    mac-turkish        	macTurkish
    mac-ukraine        	macUkraine
    maccenteuro        	macCentEuro
    maccentraleupore   	macCentEuro
    maccroatian        	macCroatian
    maccyrillic         macCyrillic
    macgreek           	macGreek
    maciceland         	macIceland
    macintosh          	macRoman
    macjapan           	macJapan
    macroman           	macRoman
    macromania         	macRomania
    macthai            	macThai
    macturkish          macTurkish
    macukraine         	macUkraine
    shift_jis          	shiftjis
    us-ascii           	ascii
    windows-1250       	cp1250
    windows-1251       	cp1251
    windows-1252       	cp1252
    windows-1253       	cp1253
    windows-1254       	cp1254
    windows-1255       	cp1255
    windows-1256       	cp1256
    windows-1257       	cp1257
    windows-1258       	cp1258
    x-mac              	macRoman
    x-mac-centeuro      macCentEuro
    x-mac-centraleupore macCentEuro
    x-mac-croatian      macCroatian
    x-mac-cyrillic      macCyrillic
    x-mac-greek         macGreek
    x-mac-iceland       macIceland
    x-mac-japan         macJapan
    x-mac-roman         macRoman
    x-mac-romania       macRomania
    x-mac-thai          macThai
    x-mac-turkish       macTurkish
    x-mac-ukraine       macUkraine
    x-macintosh         macRoman
  }

  HttpCore instproc set_default_port {protocol} {
    switch -- $protocol {
      http  {my set port 80}
      https {my set port 443}
    }
  }

  HttpCore instproc parse_url {} {
    my instvar protocol url host port path
    if {[regexp {^(http|https)://([^/]+)(/.*)?$} $url _ protocol host path]} {
      # Be friendly and allow strictly speaking invalid urls 
      # like "http://www.openacs.org"  (no trailing slash)
      if {$path eq ""} {set path /}
      my set_default_port $protocol
      regexp {^([^:]+):(.*)$} $host _ host port
    } else {
      error "unsupported or invalid url '$url'"
    }
  }

  HttpCore instproc open_connection {} {
    my instvar host port S
    set S [socket -async $host $port]
  }

  HttpCore instproc set_encoding {
    {-text_translation {auto binary}} 
    content_type
  } {
    #
    # for text, use translation with optional encodings, 
    # else set translation binary
    #
    if {[string match "text/*" $content_type]} {
      if {[regexp {charset=([^ ]+)$} $content_type _ encoding]} {
	[self class] instvar http_to_tcl_encodings
	set enc [string tolower $encoding]
	if {[info exists http_to_tcl_encodings($enc)]} {
          set enc $http_to_tcl_encodings($enc)
        }
	fconfigure [my set S] \
	    -translation $text_translation \
	    -encoding $enc
      } else {
	fconfigure [my set S] -translation $text_translation
      }
    } else {
      fconfigure [my set S] -translation binary
    }
  }

  HttpCore instproc init {} {
    my instvar S post_data host port protocol
    my destroy_on_cleanup
    my set meta [list]
    my set data ""
    if {[my exists url]} {
      my parse_url
    } else {
      if {![info exists port]} {my set_default_port $protocol}
      if {![info exists host]} {
        error "either host or url must be specified"
      }
    }
    if {$protocol eq "https"} {
      package require tls
      if {[info command ::tls::import] eq ""} {
        error "https request require the Tcl module TLS to be installed\n\
             See e.g. http://tls.sourceforge.net/"
      }
      # 
      # Add HTTPs handling
      #
      my mixin add ::xo::Tls
    }
    if {[catch {my open_connection} err]} {
      my cancel "error during open connection via $protocol to $host $port: $err"
    }
  }

  HttpCore instproc send_request {} {
    my instvar S post_data host
    if {[catch {
      set method [expr {$post_data eq "" ? "GET" : "POST"}]
      puts $S "$method [my path] HTTP/1.0"
      puts $S "Host: $host"
      puts $S "User-Agent: [my user_agent]"
      foreach {tag value} [my request_header_fields] {
	#regsub -all \[\n\r\] $value {} value
	#set tag [string trim $tag]
        puts $S "$tag: $value"
      }
      my $method
    } err]} {
      my cancel "error send $host [my port]: $err"
      return
    }
  }

  HttpCore instproc GET {} {
    my instvar S
    puts $S ""
    my request_done
  }

  HttpCore instproc POST {} {
    my instvar S post_data
    if {[string match "text/*" [my content_type]]} {
      # Make sure, "string range" and "string length" return the right
      # values for UTF-8 and other encodings.
      set post_data [encoding convertto $post_data]
    }
    puts $S "Content-Length: [string length $post_data]"
    puts $S "Content-Type: [my content_type]"
    puts $S ""
    my set_encoding [my content_type]
    my send_POST_data
  }
  HttpCore instproc send_POST_data {} {
    my instvar S post_data
    puts -nonewline $S $post_data
    my request_done
  }
  HttpCore instproc request_done {} {
    my instvar S
    flush $S
    my reply_first_line
  }

  HttpCore instproc close {} {
    my debug "--- closing socket"
    catch {close [my set S]}
  }

  HttpCore instproc cancel {reason} {
    my set status canceled
    my set cancel_message $reason
    my debug "--- $reason"
    my close
  }

  HttpCore instproc finish {} {
    my set status finished
    my close
    my debug "--- [my host] [my port] [my path] has finished"
  }
  HttpCore instproc getLine {var} {
    my upvar $var response
    my instvar S
    set n [gets $S response]
    if {[eof $S]} {
      my log "--premature eof"
      return -2
    }
    if {$n == -1} {my debug "--input pending, no full line"; return -1}
    return $n
  }
  HttpCore instproc reply_first_line {} {
    my instvar S status_code
    fconfigure $S -translation crlf
    set n [my getLine response]
    switch -exact -- $n {
      -2 {my cancel premature-eof; return}
      -1 {my finish; return}
    }
    if {[regexp {^HTTP/([0-9.]+) +([0-9]+) *} $response _ \
	     responseHttpVersion status_code]} {
      my reply_first_line_done
    } else {
      my log "--unexpected response '$response'"
      my cancel unexpected-response
    }
  }
  HttpCore instproc reply_first_line_done {} {
    my header
  }
  HttpCore instproc header {} {
    while {1} {
      set n [my getLine response]
      switch -exact -- $n {
	-2 {my cancel premature-eof; return}
	-1 {continue}
	0 {break}
	default {
	  #my debug "--header $response"
	  if {[regexp -nocase {^content-length:(.+)$} $response _ length]} {
	    my set content_length [string trim $length]
	  } elseif {[regexp -nocase {^content-type:(.+)$} $response _ type]} {
	    my set content_type [string trim $type]
	  }
	  if {[regexp -nocase {^([^:]+): *(.+)$} $response _ key value]} {
	    my lappend meta [string tolower $key] $value
	  }
	}
      }
    }
    my reply_header_done
  }
  HttpCore instproc reply_header_done {} {
    # we have received the header, including potentially the 
    # content_type of the returned data
    my set_encoding [my content_type]
    if {[my exists content_length]} {
      my set data [read [my set S] [my set content_length]]
    } else {
      my set data [read [my set S]]
    }
    my finish
  }

  HttpCore instproc set_status {key newStatus {value ""}} {
    nsv_set bgdelivery $key [list $newStatus $value]
  }

  HttpCore instproc unset_status {key} {
    nsv_unset bgdelivery $key
  }

  HttpCore instproc exists_status {key} {
    return [nsv_exists bgdelivery $key]
  }

  HttpCore instproc get_status {key} {
    return [lindex [nsv_get bgdelivery $key] 0]
  }

  HttpCore instproc get_value_for_status {key} {
    return [lindex [nsv_get bgdelivery $key] 1]
  }



  #
  # Synchronous (blocking) requests
  #

  Class HttpRequest -superclass HttpCore -slots {
    Attribute timeout -type integer
  }

  HttpRequest instproc init {} {
    if {[my exists timeout] && [my timeout] > 0} {
      # create a cond and mutex
      set cond  [thread::cond create]
      set mutex [thread::mutex create]
      
      thread::mutex lock $mutex
     
      # start the asynchronous request
      my debug "--a create new  ::xo::AsyncHttpRequest"
      set req [bgdelivery do -async ::xo::AsyncHttpRequest new \
		   -mixin ::xo::AsyncHttpRequest::RequestManager \
		   -url [my url] \
		   -timeout [my timeout] \
		   -post_data [encoding convertto [my post_data]] \
		   -request_header_fields [my request_header_fields] \
		   -content_type [my content_type] \
		   -user_agent [my user_agent] \
		   -condition $cond]

      while {1} {
	my set_status $cond COND_WAIT_TIMEOUT
	thread::cond wait $cond $mutex [my timeout]

	set status [my get_status $cond]
	my debug "status after cond-wait $status"

	if {$status ne "COND_WAIT_REFRESH"} break
      }
      if {$status eq "COND_WAIT_TIMEOUT"} {
	my set_status $cond "COND_WAIT_CANCELED"
      }
      set status_value [my get_value_for_status $cond]
      if {$status eq "JOB_COMPLETED"} {
	my set data $status_value
      } else {
	set msg "Timeout-constraint, blocking HTTP request failed. Reason: '$status'" 
	if {$status_value ne ""} {
	  append msg " ($status_value)"
	}
	error $msg
      }
      thread::cond destroy $cond
      thread::mutex unlock $mutex
      thread::mutex destroy $mutex
      my unset_status $cond
    } else {
      next    ;# HttpCore->init
      #
      # test whether open_connection yielded
      # a socket ...
      #
      if {[my exists S]} {
	my send_request
      }
    }
  }
    
  #
  # Asynchronous (non-blocking) requests
  #

  Class AsyncHttpRequest -superclass HttpCore -slots {
    Attribute timeout -type integer -default 10000 ;# 10 seconds
    Attribute request_manager
  }
  AsyncHttpRequest instproc set_timeout {} {
    my cancel_timeout
    my debug "--- setting socket timeout: [my set timeout]"
    my set timeout_handle [after [my set timeout] [self] cancel timeout]
  }
  AsyncHttpRequest instproc cancel_timeout {} {
    if {[my exists timeout_handle]} {
      after cancel [my set timeout_handle]
    }
  }
  AsyncHttpRequest instproc send_request {} {
    # remove fileevent handler explicitly
    fileevent [my set S] writable {}
    next
  }
  AsyncHttpRequest instproc init {} {
    my notify start_request
    my set_timeout
    next
    #
    # test whether open_connection yielded
    # a socket ...
    #
    if {[my exists S]} {
      fileevent [my set S] writable [list [self] send_request]
    }
  }
  AsyncHttpRequest instproc notify {method {arg ""}} {
    if {[my exists request_manager]} {
      [my request_manager] $method $arg [self]
    }
  }
  AsyncHttpRequest instproc POST {} {
    if {[my exists S]} {fconfigure [my set S] -blocking false}
    fileevent [my set S] writable [list [self] send_POST_data]
    my set bytes_sent 0
    next
  }
  AsyncHttpRequest instproc send_POST_data {} {
    my instvar S post_data bytes_sent
    my set_timeout
    set l [string length $post_data]
    if {$bytes_sent < $l} {
      set to_send [expr {$l - $bytes_sent}]
      set block_size [expr {$to_send < 4096 ? $to_send : 4096}]
      set bytes_sent_1 [expr {$bytes_sent + $block_size}]
      set block [string range $post_data $bytes_sent $bytes_sent_1]
      my notify request_data $block
      puts -nonewline $S $block
      set bytes_sent $bytes_sent_1
    } else {
      fileevent $S writable ""
      my request_done
    }
  }
  AsyncHttpRequest instproc cancel {reason} {
    if {$reason ne "timeout"} {
      my cancel_timeout
    }
    next
    my debug "--- canceled for $reason"
    my notify failure $reason
  }
  AsyncHttpRequest instproc finish {} {
    my cancel_timeout
    next
    my debug "--- finished data [my set data]"
    my notify success [my set data]
  }
  AsyncHttpRequest instproc request_done {} {
    my notify start_reply
    my set_timeout
    my instvar S
    flush $S
    fconfigure $S -blocking false
    fileevent $S readable [list [self] reply_first_line]
  }
  AsyncHttpRequest instproc reply_first_line_done {} {
    my set_timeout
    my instvar S
    fileevent $S readable [list [self] header]      
  }
  AsyncHttpRequest instproc reply_header_done {} {
    my set_timeout
    # we have received the header, including potentially the 
    # content_type of the returned data
    my set_encoding [my content_type]
    fileevent [my set S] readable [list [self] receive_reply_data]
  }
  AsyncHttpRequest instproc receive_reply_data {} {
    my instvar S
    my debug "JOB receive_reply_data eof=[eof $S]"
    if {[eof $S]} {
      my finish
    } else {
      my set_timeout
      set block [read $S]
      my notify reply_data $block
      my append data $block
      #my debug "reveived [string length $block] bytes"
    }
  }

  #
  # Mixin class, used to turn instances of
  # AsyncHttpRequest into result callbacks
  # in the scope of bgdelivery, realising
  # the blocking-timeout feature ...
  #

  Class create AsyncHttpRequest::RequestManager \
      -slots {
	Attribute condition
      } -instproc finalize {obj status value} {
	# set the result and do the notify
	my instvar condition
	# If a job was canceled, the status variable might not exist
	# anymore, the condition might be already gone as well.  In
	# this case, we do not have to perform the cond-notify.
	if {[my exists_status $condition] && 
	    [my get_status $condition] eq "COND_WAIT_REFRESH"} {
          # Before, we had here COND_WAIT_TIMEOUT instead of 
          # COND_WAIT_REFRESH
	  my set_status $condition $status $value
	  catch {thread::cond notify $condition}
	  $obj debug "--- destroying after finish"
	  $obj destroy
	}

      } -instproc set_cond_timeout {} {
	my instvar condition
	if {[my exists_status $condition] && 
	    [my get_status $condition] eq "COND_WAIT_TIMEOUT"} {
	  my set_status $condition COND_WAIT_REFRESH
	  catch {thread::cond notify $condition}
	}
	
      } -instproc start_request {payload obj} {
	my debug "JOB start request $obj"
	my set_cond_timeout

      } -instproc request_data {payload obj} {
	my debug "JOB request data $obj [string length $payload]"
	my set_cond_timeout

      } -instproc start_reply {payload obj} {
	my debug "JOB start reply $obj"
	my set_cond_timeout

      } -instproc reply_data {payload obj} {
	my debug "JOB reply data $obj [string length $payload]"
	my set_cond_timeout

      } -instproc success {payload obj} {
	my finalize $obj "JOB_COMPLETED" $payload

      } -instproc failure {reason obj} {
	my finalize $obj "JOB_FAILED" $reason

      } -instproc init {} {
	# register request object as its own request_manager
	my request_manager [self]
	next

      } -instproc cancel {reason} {
	next
	my debug "--- destroying after cancel"
	my destroy

      } -instproc unknown {method args} {
	my log "UNKNOWN $method"
      }
  
  # 
  # TLS/SSL support
  #
  # Perform HTTPS requests via TLS (does not require nsopenssl)
  # - requires tls 1.5.0 to be compiled into <aolsever>/lib/ ...
  # - - - - - - - - - - - - - - - - - - 
  # - see http://www.ietf.org/rfc/rfc2246.txt
  # - http://wp.netscape.com/eng/ssl3/3-SPEC.HTM
  # - - - - - - - - - - - - - - - - - - 
  
  Class Tls
  Tls instproc open_connection {} {
    my instvar S
    #
    # first perform regular initialization of the socket
    #
    next
    #
    # then import tls (could configure it here in more detail)
    #
    ::tls::import $S
  }
  

  #
  # Trace Requests
  #                                 

  Class HttpRequestTrace 
  nsv_set HttpRequestTrace count 0

  HttpRequestTrace instproc init {} {
    my instvar F post_data
    my set meta [list]
    my set requestCount [nsv_incr HttpRequestTrace count]  ;# make it an instvar to find it in the log file
    set F [open /tmp/req-[format %.4d [my set requestCount]] w]
    
    set method [expr {$post_data eq "" ? "GET" : "POST"}]
    puts $F "$method [my path] HTTP/1.0"
    puts $F "Host: [my host]"
    puts $F "User-Agent: [my user_agent]"
    foreach {tag value} [my request_header_fields] { puts $F "$tag: $value" }
    next 
  }

  HttpRequestTrace instproc POST {} {
    my instvar F post_data
    puts $F "Content-Length: [string length $post_data]"
    puts $F "Content-Type: [my content_type]"
    puts $F ""
    fconfigure $F -translation {auto binary}
    puts -nonewline $F $post_data
    next
  }

  HttpRequestTrace instproc cancel {reason} {
    catch {close [my set F]}
    next
  }
  HttpRequestTrace instproc finish {} {
    catch {close [my set F]}
    next
  }
   
  #
  # To activate trace for all requests, uncomment the following line.
  # To trace a single request, mixin ::xo::HttpRequestTrace into the request.
  #                           
  # HttpCore instmixin add ::xo::HttpRequestTrace
}
