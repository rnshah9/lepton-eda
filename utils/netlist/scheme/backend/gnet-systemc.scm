;;; Lepton EDA netlister
;;; Copyright (C) 1998-2010 Ales Hvezda
;;; Copyright (C) 1998-2017 gEDA Contributors
;;; Copyright (C) 2017-2020 Lepton EDA Contributors
;;;
;;; This program is free software; you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 2 of the License, or
;;; (at your option) any later version.
;;;
;;; This program is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with this program; if not, write to the Free Software
;;; Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

;;
;; SystemC netlist backend written by Jaume Masip
;; (based on gnet-verilog.scm by Mike Jarabek)

;; some useful regexes for working with net-names
;;
(use-modules (ice-9 regex)
             (ice-9 match)
             (srfi srfi-1)
             (srfi srfi-26)
             (netlist port)
             (netlist schematic)
             (netlist schematic toplevel))

(define id-regexp "[a-zA-Z_][a-zA-Z0-9_$]*")
(define numeric  "[0-9]+")
;; match on a systemc identifier like:  netname[x:y]
(define bit-range-reg (make-regexp
                       (string-append "^(" id-regexp ")[[:space:]]*"
                                      "\\["
                                      "[[:space:]]*(" numeric ")[[:space:]]*"
                                      ":"
                                      "[[:space:]]*(" numeric ")[[:space:]]*"
                                      "\\]")))

;; match on a systemc identifier like:  netname[x]
(define single-bit-reg (make-regexp
                        (string-append "^(" id-regexp ")[[:space:]]*"
                                       "\\["
                                       "[[:space:]]*(" numeric ")[[:space:]]*"
                                       "\\]" )))

;; match on a systemc identifier like:  netname<type>
(define systemc-reg (make-regexp
                        (string-append "^(" id-regexp ")[[:space:]]*"
                                       "<"
                                       "[[:space:]]*(" id-regexp ")[[:space:]]*"
                                       ">" )))

;; match on a systemc identifier like:  netname
(define simple-id-reg (make-regexp
                       ( string-append "^(" id-regexp ")$" )))


;;; Returns a list of first pin netnames for those packages in
;;; PACKAGE-LIST that have an attribute named ATTRIBUTE which
;;; value is VALUE.
(define (systemc:filter attribute value package-list)
  (define (get-package-pin-netnames package)
    (and (string=? (gnetlist:get-package-attribute package attribute)
                   value)
         (pin-netname package (car (get-pins package)))))

  (filter-map get-package-pin-netnames package-list))


;;
;; Output the guts of the module ports here
;;
;; Scan through the list of components, and pins from each one, finding the
;; pins that have PINTYPE == CHIPIN, CHIPOUT, CHIPTRI (for inout)
;; build three lists one each for the inputs, outputs and inouts
;; return the a list of three lists that contain the pins in the order
;; we want.
(define (systemc:get-port-list packages)
  ;; construct list
  (list (systemc:filter "device" "IPAD" packages)
        (systemc:filter "device" "OPAD" packages)
        (systemc:filter "device" "IOPAD" packages)))

;;
;; output the meat of the module port section
;;
;; each line in the declaration is formatted like this:
;;
;;       PORTNAME , <newline>
;;
(define (systemc:write-module-declaration module-name port-list packages)
  (display "#include \"systemc.h\"\n")
  (for-each
   (lambda (package)                         ; loop on packages
     (let ((device (get-device package)))
       (if (not (schematic-port-device-string? device))
           (format #t "#include \"~A.h\"\n" device))))
   packages)
  (format #t "\nSC_MODULE (~A)\n{\n" module-name))


;;; Outputs the module direction section for PORT-LIST which is a
;;; list of lists of the form (in-ports out-ports inout-ports)
(define (systemc:write-port-directions port-list)
  (define (write-pin-direction type pin)
    (format #t "sc_~A<bool> ~A;\n" type (systemc:netname pin)))

  (display "/* Port directions begin here */\n")
  (for-each
   (lambda (type ports)
     (for-each (cut write-pin-direction type <>) ports))
   '(in out inout) port-list))


;;
;; Top level header
;;

(define (systemc:write-top-header module-name packages)
  (let ((port-list (systemc:get-port-list packages)))
    (begin
      (display "/* structural SystemC generated by lepton-netlist */\n")
      (display "/* WARNING: This is a generated file, edits       */\n")
      (display "/*        made here will be lost next time        */\n")
      (display "/*        you run gnetlist!                       */\n")
      (display "/* Id ........gnet-systemc.scm (04/09/2003)       */\n")
      (display "/* Source...../home/geda/gnet-systemc.scm         */\n")
      (display "/* Revision...0.3 (23/09/2003)                    */\n")
      (display "/* Author.....Jaume Masip                         */\n")
      (newline)
      (systemc:write-module-declaration module-name
                                        port-list
                                        packages)
      (newline)
      (systemc:write-port-directions port-list)
      (newline))))


;;
;; Take a netname and parse it into a structure that describes the net:
;;
;;    (   netname            ; name of the wire
;;      ( N1                 ; first limit
;;        N2                 ; second limit
;;        Increasing_order   ; #t if N2>N1
;;        sure               ; #t if we are sure about the order
;;      ))
(define systemc:net-parse
  (lambda (netname)
    (let
        ((bit-range (regexp-exec bit-range-reg netname))
         (single-bit (regexp-exec single-bit-reg netname))
         (simple-id (regexp-exec simple-id-reg netname))
         (systemc   (regexp-exec systemc-reg netname)))

      ;; check over each expression type, and build the appropriate
      ;; result
      (cond
       ;; is it a bit range?
       (bit-range
        (list (match:substring bit-range 1)
              (list (string->number (match:substring bit-range 2))
                    (string->number (match:substring bit-range 3))
                    (> (string->number (match:substring bit-range 3))
                       (string->number (match:substring bit-range 2)))
                    '#t netname)))

       ;; just a single bit?
       (single-bit
        (list (match:substring single-bit 1)
              (list (string->number (match:substring single-bit 2))
                    (string->number (match:substring single-bit 2))
                    '#f '#f netname)))

       ;; just a systemc signal?
       (systemc
         (begin
           (list (match:substring systemc 1)
             (list (string->number (match:substring systemc 2))
               (match:substring systemc 2)
                    '#f '#f netname)))
)

       ;; or a net without anything
       (simple-id
        ;(display "bare-net")
        (list (match:substring simple-id 1) (list 0 0 #f #f netname)))

       (else
        (display
         (string-append "Warning: `" netname
                        "' is not likely a valid Verilog identifier"))
        (newline)
        (list netname (list 0 0 #f #f netname)))
       )))
)


;;
;; return just the netname part of a systemc identifier
;;
(define systemc:netname
  (lambda (netname)
    (car (systemc:net-parse netname))))

;;  Update the given bit range with data passed.  Take care
;;  of ordering issues.
;;
;;   n1     : new first range
;;   n2     : new second range
;;   old-n1 : first range to be updated
;;   old-n2 : second range to be updated
;;   increasing : original order was increasing
(define systemc:update-range
  (lambda (n1 n2 old-n1 old-n2 increasing)
    (let ((rn1 (if increasing
                   (min n1 old-n1)     ; originally increasing
                   (max n1 old-n1)))   ; originally decreasing

          (rn2 (if increasing
                   (max n2 old-n2)     ; originally increasing
                   (min n2 old-n2))))
      (list rn1 rn2)

      )))


;; return a record that has been updated with the given
;; parameters
(define systemc:update-record
  (lambda (n1
           n2
           list-n1
           list-n2
           increasing
           sure
           real)
    (list
     (append (systemc:update-range
              n1 n2 list-n1 list-n2
              increasing)
             (list increasing
                   sure
                   real)))))

;;
;;  Work over the list of `unique' nets in the design,
;;  extracting names, and bit ranges, if appropriate.
;;  return a list of net description objects
;;

(define systemc:get-nets '())

(define (systemc:get-nets-once! nets)
  (define the-nets '())
  (set! systemc:get-nets
        (begin
          (for-each
           (lambda (netname)
             ;; parse the netname, and see if it is already on the list
             (let* ((parsed (systemc:net-parse netname))
                    (listed (assoc (car parsed) the-nets)))

               (if listed
                   ;; it is, do some checks, and update the record
                   ;; extract fields from list
                   (let* ((list-name       (first listed))
                          (list-n1         (first (second listed)))
                          (list-n2         (second (second listed)))
                          (list-increasing (third (second listed)))
                          (list-sure       (fourth (second listed)))
                          (list-real       (fifth (second listed)))

                          (name            (first parsed))
                          (n1              (first (second parsed)))
                          (n2              (second (second parsed)))
                          (increasing      (third (second parsed)))
                          (sure            (fourth (second parsed)))
                          (real            (fifth (cdr (second parsed))))

                          (consistant      (or (and list-increasing increasing)
                                               (and (not list-increasing)
                                                    (not increasing))))

                          )

                     (cond
                      ((and list-sure consistant)
                       (set-cdr! listed
                                 (systemc:update-record n1 n2
                                                        list-n1 list-n2
                                                        increasing
                                                        #t
                                                        real)
                                 ))
                      ((and list-sure (not sure) (zero? n1) (zero? n2))
                       '() ;; this is a net without any expression, leave it
                       )
                      ((and list-sure (not consistant))
                       ;; order is inconsistent
                       (format #t
                               "Warning: Net `~A' has a bit order that conflicts with the original definition of `~A', ignoring `~A'\n"
                               real
                               list-real
                               real))
                      ((and (not list-sure) sure consistant)
                       (set-cdr! listed
                                 (systemc:update-record n1 n2
                                                        list-n1 list-n2
                                                        increasing
                                                        #t
                                                        real)))

                      ((and (not list-sure) sure (not consistant))
                       (set-cdr! listed
                                 (systemc:update-record n1 n2
                                                        list-n2 list-n1
                                                        increasing
                                                        #t
                                                        real)))
                      ((and (not list-sure) (not sure))
                       (set-cdr! listed
                                 (systemc:update-record n1 n2
                                                        list-n1 list-n2
                                                        increasing
                                                        #f
                                                        real)))
                      (else (display "This should never happen!\n"))))
                   ;; it is not, just add it to the end
                   (set! the-nets
                         (append the-nets
                                 (list parsed))))))

           nets)
          the-nets))
  systemc:get-nets)

;;
;;  Loop over the list of nets in the design, writing one by one
;;
(define (systemc:write-wires)
  (display "/* Wires from the design */\n")
  (for-each
   (lambda (wire)
     ;; print a wire statement for each
     (format #t "sc_signal<~A> ~A;\n"
             (second (second wire))
             ;; wire name
             (first wire)))
            systemc:get-nets)
  (newline))

;;
;;  Output any continuous assignment statements generated
;; by placing `high' and `low' components on the board
;;
(define (systemc:write-continuous-assigns packages)
  ;; do high values
  ;; XXX fixme, multiple bit widths!
  (for-each
   (lambda (wire) (format #t "assign ~A = 1'b1;\n" wire))
   (systemc:filter "device" "HIGH" packages))

  ;; XXX fixme, multiple bit widths!
  (for-each
   (lambda (wire) (format #t "assign ~A = 1'b0;\n" wire))
   (systemc:filter "device" "LOW" packages))

  (newline))



;;
;; Top level component writing
;;
;; Output a compoment instatantiation for each of the
;; components on the board
;;
;; use the format:
;;
;;  device-attribute refdes (
;;        .pinname ( net_name ),
;;        ...
;;    );
;;

(define (systemc:components module-name packages)
  (define attrib-names (map (cut format #f "attr~A" <>) (iota 32 1)))

  (define (package->package-attribs package)
    (let ((attrib-values (filter-map known?
                                     (map (cut gnetlist:get-package-attribute
                                               package
                                               <>)
                                          attrib-names))))
      (format #f "    ~A(\"~A~A\")"
              package package (string-join attrib-values "\",\""))))

  (define (package->device-package package device)
    (format #f "~A ~A;\n" device package))

  ;; Output a module connections for the package given to us with named ports.
  (define (package->connections package)
    (define pinnumber car)
    (define netname cdr)
    (let ((pin-net-list (get-pins-nets package)))
      (and (not (null? pin-net-list))
           (string-join
            (filter-map
             (lambda (pin-net)
               (and (not (string-prefix-ci? "unconnected_pin" (netname pin-net)))
                    ;; if this module wants positional pins,
                    ;; then output that format, otherwise
                    ;; output normal named declaration
                    (let ((positional? (string=? (gnetlist:get-package-attribute package
                                                                                 "VERILOG_PORTS")
                                                 "POSITIONAL")))
                      (format #f
                              "    ~A~A;\n"
                              package
                              (pin-net->string pin-net positional?)))))
             pin-net-list)
            ""))))

  (define (get-package-strings package)
    (let ((device (gnetlist:get-package-attribute package "device")))
      (and (not (schematic-port-device-string? device))
           `(,(package->device-package package device)
             ,(package->package-attribs package)
             ,(package->connections package)))))

  (let ((package-data (filter-map get-package-strings packages)))
    (match package-data
      (((device-package attribs connections) ...)
       (format #t
               "/* Package instantiations */
~A
SC_CTOR(~A):
~A
  {
~A  }
};

"
               (string-join device-package "")
               module-name
               (string-join attribs ",\n")
               (string-join (filter identity connections) "\n")))
      (_ #f))))


;;
;; Display the individual net connections
;;  in this format if positional is true:
;;
;;    /* PINNAME */ NETNAME
;;
;;  otherwise emit:
;;
;;      .PINNAME ( NETNAME )
;;
(define (pin-net->string pin-net positional)
  (define pinnumber car)
  (define netname cdr)
  (let ((systemc (regexp-exec systemc-reg (netname pin-net))))
    (if positional
        ;; Output a positional port instance.
        ;; In name is added for debugging.
        (format #f "  /* ~A */ ~A" (pinnumber pin-net) (netname pin-net))
        ;; Else output a named port instance.
        (format #f ".~A(~A)"
                ;; Display the escaped version of the identifier.
                (pinnumber pin-net)
                (if systemc
                    (match:substring systemc 1)
                    (netname pin-net))))))



;;; Highest level function
;;; Write Structural systemc representation of the schematic
;;;
(define (systemc output-filename)
  (let ((nets (schematic-nets (toplevel-schematic)))
        (packages (schematic-package-names (toplevel-schematic)))
        ;; top level block name for the module
        (module-name (or (schematic-toplevel-attrib (toplevel-schematic)
                                                    'module_name)
                         "not found")))
    (systemc:get-nets-once! nets)
    (systemc:write-top-header module-name packages)
    (systemc:write-wires)
    (systemc:write-continuous-assigns packages)
    (systemc:components module-name packages)))