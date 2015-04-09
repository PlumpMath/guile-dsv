;;; rfc4180.scm -- DSV parser for RFC 4180 format.

;; Copyright (C) 2015 Artyom V. Poptsov <poptsov.artyom@gmail.com>
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; The program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with the program.  If not, see <http://www.gnu.org/licenses/>.


;;; Commentary:


;;; Code:

(define-module (dsv unix)
  #:use-module (ice-9 rdelim)
  #:use-module (srfi  srfi-1)
  #:use-module (srfi  srfi-26)
  #:use-module ((string transform)
                #:select (escape-special-chars))
  #:export (dsv->scm
            dsv-string->scm
            scm->dsv
            scm->dsv-string
            guess-delimiter))

;; List of known delimiters
(define %known-delimiters '(#\, #\: #\; #\| #\tab #\space))


(define (string-split/escaped str delimiter)
  "Split a string STR into the list of the substrings delimited by appearances
of the DELIMITER.

This procedure is simlar to string-split, but works correctly with
escaped delimiter -- that is, skips it.  E.g.:

  (string-split/escaped \"car:cdr:ca\\:dr\" #\\:)
  => (\"car\" \"cdr\" \"ca\\:dr\")
"
  (let ((fields (string-split str delimiter)))
    (fold (lambda (field prev)
            (if (and (not (null? prev))
                     (string-suffix? "\\" (last prev)))
                (append (drop-right prev 1)
                        (list (string-append
                               (string-drop-right (last prev) 1)
                               (string delimiter)
                               field)))
                (append prev (list field))))
          '()
          fields)))


(define (dsv-string->scm str delimiter)
    (string-split/escaped str delimiter))

(define (dsv->scm port delimiter comment-symbol)

  (define (commented? line)
    "Check if the LINE is commented."
    (string-prefix? (string comment-symbol) (string-trim line)))

  (let parse ((dsv-list '())
              (line     (read-line port)))
    (if (not (eof-object? line))
        (if (not (commented? line))
            (parse (cons (dsv-string->scm line delimiter) dsv-list)
                   (read-line port))
            (parse dsv-list (read-line port)))
        (reverse dsv-list))))

(define (scm->dsv scm port delimiter)

  (define (->dsv lst)
    (string-join (map (cut escape-special-chars <> delimiter #\\)
                      lst)
                 (string delimiter)))

  (for-each (cut write-line <> port)
            (map ->dsv scm)))

(define (scm->dsv-string lst delimiter)
  (call-with-output-string (cut scm->dsv lst <> delimiter)))


(define (guess-delimiter str)
  "Guess a DSV string STR delimiter."
  (let* ((delimiter-list
          (map (lambda (d)
                 (cons d (length (string-split/escaped str d))))
               %known-delimiters))
         (guessed-delimiter-list
          (fold (lambda (a prev)
                  (if (not (null? prev))
                      (let ((a-count (cdr a))
                            (b-count (cdar prev)))
                        (cond ((> a-count b-count) (list a))
                              ((= a-count b-count) (append (list a) prev))
                              (else prev)))
                      (list a)))
                '()
                delimiter-list)))
    (and (= (length guessed-delimiter-list) 1)
         (caar guessed-delimiter-list))))

;;; unix.scm ends here
