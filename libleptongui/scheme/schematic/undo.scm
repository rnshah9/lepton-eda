;; Lepton EDA Schematic Capture
;; Scheme API
;; Copyright (C) 2017 dmn <graahnul.grom@gmail.com>
;; Copyright (C) 2017-2022 Lepton EDA Contributors
;;
;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 2 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; if not, write to the Free Software
;; Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
;;

( define-module  ( schematic undo )
  #:use-module (system foreign)

  #:use-module (schematic ffi)
  #:use-module (schematic window)

    ; public:
    ;
    #:export     ( undo-save-state )

) ; define-module


;;; Variables defined in defines.h for C code.
(define UNDO_ALL 0)
(define UNDO_VIEWPORT_ONLY 1)

(define (undo-save-state)
  "Saves current state onto the undo stack.  Returns #t on
success, #f on failure."
  (define *window (current-window))

  (let ((*view (gschem_toplevel_get_current_page_view *window)))
    (and (not (null-pointer? *view))
         (let ((*page (gschem_page_view_get_page *view)))
           (and (not (null-pointer? *page))
                (o_undo_savestate *window *page UNDO_ALL)
                #t)))))
