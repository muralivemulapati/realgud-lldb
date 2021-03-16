;; Copyright (C) 2016-2019 Free Software Foundation, Inc
;; Author: Rocky Bernstein <rocky@gnu.org>

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;  `realgud--lldb' Main interface to lldb via Emacs
(require 'load-relative)
(require 'realgud)
(require-relative-list '("core" "track-mode") "realgud--lldb-")

;; This is needed, or at least the docstring part of it is needed to
;; get the customization menu to work in Emacs 25.
(defgroup realgud--lldb nil
  "The realgud interface to lldb"
  :group 'realgud
  :version "25.1")

;; -------------------------------------------------------------------
;; User definable variables
;;

(defcustom realgud--lldb-command-name
  "lldb"
  "File name for executing the and command options.
This should be an executable on your path, or an absolute file name."
  :type 'string
  :group 'realgud--lldb)

(declare-function realgud--lldb-track-mode     'realgud--lldb-track-mode)
(declare-function realgud-command              'realgud-send)
(declare-function realgud--lldb-parse-cmd-args 'realgud--lldb-core)
(declare-function realgud--lldb-query-cmdline  'realgud--lldb-core)
(declare-function realgud:run-process          'realgud-run)
(declare-function realgud:flatten              'realgud-utils)
(declare-function realgud:remove-ansi-schmutz  'realgud-utils)

;; -------------------------------------------------------------------
;; The end.
;;

(defun realgud--lldb-pid-command-buffer (pid)
  "Return the command buffer used when lldb attach -p PID is invoked"
  (format "*lldb %d shell*" pid)
  )

(defun realgud--lldb-find-command-buffer (pid)
  "Find among current buffers a buffer that is a realgud command buffer
running lldb on process number PID"
  (let ((find-cmd-buf "*lldb attach shell*")
        (cmd-buf-new-name (realgud--lldb-pid-command-buffer pid))
	(found-buf))
    (dolist (buf (buffer-list))
      (message "name:%s" (buffer-name buf))
      )
    (dolist (buf (buffer-list))
      (when (and (equal find-cmd-buf (buffer-name buf))
		(realgud-cmdbuf? buf)
		(get-buffer-process buf))
        (setq found-buf buf)
        (with-current-buffer buf
          (rename-buffer cmd-buf-new-name))))
    found-buf))

(defun realgud--lldb-pid (pid)
  "Start debugging lldb process with pid PID."
  (interactive "nEnter the pid that lldb should attach to: ")
  (realgud--lldb (format "%s attach -p %d" realgud--lldb-command-name pid))
  ;; FIXME: should add code to test if attach worked.
  )

(defun realgud--lldb-pid-associate (pid)
  "Start debugging lldb process with pid PID and associate the
current buffer to that realgud command buffer."
  (interactive "nEnter the pid that lldb should attach to and associate the current buffer to: ")
  (let* ((command-buf)
	 (source-buf (current-buffer))
	 )
    (realgud--lldb-pid pid)
    (setq command-buf (realgud--lldb-find-command-buffer pid))
    (if command-buf
	(with-current-buffer source-buf
	  (realgud:cmdbuf-associate))
      )))

;;;###autoload
(defun realgud--lldb (&optional opt-cmd-line no-reset)
  "Invoke the lldb debugger and start the Emacs user interface.

OPT-CMD-LINE is treated like a shell string; arguments are
tokenized by `split-string-and-unquote'.

Normally, command buffers are reused when the same debugger is
reinvoked inside a command buffer with a similar command. If we
discover that the buffer has prior command-buffer information and
NO-RESET is nil, then that information which may point into other
buffers and source buffers which may contain marks and fringe or
marginal icons is reset. See `loc-changes-clear-buffer' to clear
fringe and marginal icons.
"
  (interactive)
  (let* ((cmd-str (or opt-cmd-line (realgud--lldb-query-cmdline "lldb")))
	 (cmd-args (split-string-and-unquote cmd-str))
	 (parsed-args (realgud--lldb-parse-cmd-args cmd-args))
	 (script-args (caddr parsed-args))
	 (script-name (car script-args))
	 (parsed-cmd-args
	  (cl-remove-if 'nil (realgud:flatten parsed-args)))
	 (cmd-buf (realgud:run-process realgud--lldb-command-name
				       script-name parsed-cmd-args
				       'realgud--lldb-minibuffer-history
				       nil))
	 )
    (if cmd-buf
	(with-current-buffer cmd-buf
	  (set (make-local-variable 'realgud--lldb-file-remap)
	       (make-hash-table :test 'equal))
	  (realgud:remove-ansi-schmutz)
	  (realgud--lldb-remove-spurious-source-code-lines)
	  (realgud--lldb-postoutput-scroll-to-bottom)
	  (realgud-command "settings set frame-format \"frame #${frame.index}: ${frame.pc}{ ${module.file.basename}{\`${function.name-with-args}{${frame.no-debug}${function.pc-offset}}}}{ at ${line.file.fullpath}:${line.number}}{${function.is-optimized} [opt]}\\n\"" nil nil nil)
	  )
      )
    )
  )

(defalias 'lldb 'realgud--lldb)

(provide-me "realgud-")

;; Local Variables:
;; byte-compile-warnings: (not cl-functions)
;; End:
