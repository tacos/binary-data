(defpackage #:nixeagle.binary-data
  (:use :cl :closer-mop :nutils)
  (:nicknames :binary-data)
  #.(let (list)
      (do-external-symbols (s :closer-mop)
        (push s list))
      `(:shadowing-import-from :closer-mop ,@list)))

(in-package :nixeagle.binary-data)

(defclass binary-data-object (standard-object)
  ()
  (:documentation
   "Base object class for all classes dealing with binary data.

This will be used in generic functions and method specializers as the base
class. All classes have to be compatable with these methods or implement
modifications so they do the right thing."))

(defclass binary-data-metaclass (standard-class)
  ()
  (:default-initargs :direct-superclasses (list (find-class 'binary-data-object))))

(defgeneric endian (object)
  (:documentation "Returns a keyword indicating the `endian' of OBJECT.

Values that make sense as of [2010-05-06 Thu 01:59] are:
    - :little-endian
    - :big-endian"))

(defclass endian-mixin ()
  ())

(defclass big-endian (endian-mixin)
  ())

(defclass little-endian (endian-mixin)
  ())

(defgeneric bit-size-of (thing)
  (:documentation "Size of THING in bits."))

(defmethod bit-size-of ((object binary-data-object))
  (reduce #'+ (class-slots (class-of object)) :key #'bit-size-of))

(defgeneric size-of (thing)
  (:documentation "Size of THING in octets which are also bytes.

If machine has a different number of bits to represent an octet, define an
additional method that specializes on that machine's class."))

(defmethod size-of ((object binary-data-object))
  "Standard machine byte is 8 bits."
  (ceiling (bit-size-of object) 8))

(defclass bit-field-slot-definition (standard-slot-definition)
  ((bit-field-size :accessor bit-size-of :initarg :bits
                   :initform nil)))

(defmethod initialize-instance :around ((slot bit-field-slot-definition) &rest initargs &key octets)
  (declare (type (or null positive-fixnum) octets))
  (if octets
      (apply #'call-next-method slot :bits (* 8 octets) initargs)
      (call-next-method)))

(defmethod compute-effective-slot-definition :around
    ((class binary-data-metaclass) (name t) slot)
  (let ((effective-slot (call-next-method)))
    (setf (bit-size-of effective-slot)
          (bit-size-of (car slot)))
    effective-slot))

(defclass bit-field-direct-slot-definition (standard-direct-slot-definition
                                            bit-field-slot-definition)
   ())

(defclass bit-field-effective-slot-definition (standard-effective-slot-definition
                                               bit-field-slot-definition)
  ((bit-field-relative-position
    :initform 0
    :type non-negative-fixnum
    :initarg :position
    :accessor bit-field-relative-position
    :documentation "Position relative to first effective slot in class.")))

(defmethod validate-superclass ((class binary-data-metaclass)
                                (super standard-class))
  "bit-field classes may inherit from standard classes."
  t)

(defmethod initialize-instance :around
    ((class binary-data-metaclass)
     &rest initargs &key direct-superclasses)
  (declare (list initargs direct-superclasses))
  (if (loop for super in direct-superclasses
         thereis (subclassp super 'binary-data-object))
      (call-next-method)
      (apply #'call-next-method class
             :direct-superclasses
             (append direct-superclasses
                     (list (find-class 'binary-data-object)))
             initargs)))

(defmethod direct-slot-definition-class ((class binary-data-metaclass) &key)
  (find-class 'bit-field-direct-slot-definition))
(defmethod effective-slot-definition-class ((class binary-data-metaclass) &key)
  (find-class 'bit-field-effective-slot-definition))

(defmethod compute-slots ((class binary-data-metaclass))
  "Computes slots returning most specific first."
  ;; Copied from sbcl's src/pcl/std-class.lisp [2010-05-06 Thu 21:30]
  ;;
  ;; We do this to preserve the computed slot ordering as this order is
  ;; unspecified in the ANSI spec as well as the AMOP.
  ;;
  ;; We need our slots to be ordered most specific first.
  (let ((name-dslotds-alist ()))
    (dolist (c (reverse (class-precedence-list class)))
      (dolist (slot (class-direct-slots c))
        (let* ((name (slot-definition-name slot))
               (entry (assoc name name-dslotds-alist :test #'eq)))
          (if entry
              (push slot (cdr entry))
              (push (list name slot) name-dslotds-alist)))))
    (mapcar (lambda (direct)
              (compute-effective-slot-definition class
                                                 (car direct)
                                                 (cdr direct)))
            (nreverse name-dslotds-alist))))

(defgeneric write-object (object stream))

(defgeneric read-object (object stream))



;;; END
