"""
=============
Module kmpfit
=============

.. moduleauthor:: Hans Terlouw <J.P.Terlouw@astro.rug.nl>
.. highlight:: python
   :linenothreshold: 5

.. warning::

   This chapter is currently being written and as such incomplete.


Introduction
------------

This module provides the class Fitter, which uses the implementation
in C of
`MPFIT <http://www.physics.wisc.edu/~craigm/idl/cmpfit.html>`_,
Craig Markwardt's non-linear least squares curve fitting routines for IDL.

Class Fitter
------------
.. autoclass:: Fitter(resfunct=None, deriv=None, modfunct=None, ...)

"""

from numpy cimport import_array, npy_intp
from numpy cimport PyArray_SimpleNewFromData, NPY_DOUBLE, PyArray_DATA
import numpy
from libc.stdlib cimport calloc, free
from kmpfit cimport *

import_array()

MP_OK = {
   1: 'Convergence in chi-square value',
   2: 'Convergence in parameter value',
   3: 'Convergence in chi-square and parameter value',
   4: 'Convergence in orthogonality',
   5: 'Maximum number of iterations reached',
   6: 'ftol is too small; no further improvement',
   7: 'xtol is too small; no further improvement',
   8: 'gtol is too small; no further improvement'
}

MP_ERR = {
     0: 'General input parameter error',
   -16: 'User function produced non-finite values',
   -17: 'No user function was supplied',
   -18: 'No user data points were supplied',
   -19: 'No free parameters',
   -20: 'Memory allocation error',
   -21: 'Initial values inconsistent w constraints',
   -22: 'Initial constraints inconsistent',
   -23: 'General input parameter error',
   -24: 'Not enough degrees of freedom'
}

cdef int xmpfunc(int *mp, int n, double *x, double **fvecp, double **dvec,
                      void *private_data) except -1:
   cdef double *e, *f, *y, *fvec, *d, *cjac
   cdef int i, j, m
   cdef npy_intp* shape=[n]

   self = <Fitter>private_data
   p = PyArray_SimpleNewFromData(1, shape, NPY_DOUBLE, x)
   if self.modfunct is not None:                         # model function
      f = <double*>PyArray_DATA(self.modfunct(p, self.xvals))
      e = self.c_inverr
      y = self.c_yvals
      if mp[0]:
         m = mp[0]
         fvec = fvecp[0]
      else:
         deviates = numpy.zeros((self.m,), dtype='d')
         fvec = <double*>PyArray_DATA(deviates)
         fvecp[0] = fvec
         mp[0] = m = self.m
         self.deviates = deviates     # keep a reference to protect from GC
         self.allocres()

      for i in range(m):
         fvec[i] = (y[i] - f[i]) * e[i]
         
      if self.deriv is not None:
# +++ derivative code to be added
         pass # compute derivatives and put in 'dvec'

      return 0
   else:                                                 # residuals function
      if self.dictarg:
         deviates = self.resfunct(p, **self.resargs)
      else:
         deviates = self.resfunct(p, self.resargs)

      f = <double*>PyArray_DATA(deviates)
      if mp[0]:
         m = mp[0]
         fvec = fvecp[0]
         for i in range(m):
            fvec[i] = f[i]
      else:
         fvecp[0] = f
         mp[0] = deviates.size
         self.m = mp[0]
         self.deviates = deviates       # keep a reference to protect from GC

         self.allocres()
      
      if dvec!=NULL and self.deriv is not None:
         for i in range(n):
            self.dflags[i] = bool(<int>dvec[i])
         if self.dictarg:
            jac = self.deriv(p, self.dflags, **self.resargs)
         else:
            jac = self.deriv(p, self.dflags, self.resargs)
         cjac = <double*>PyArray_DATA(jac)
         for j in range(n):
            d = dvec[j]
            if d!=NULL:
               for i in range(m):
                  d[i] = cjac[i*n+j]

      return 0

cdef class Fitter:
   """
:param resfunct:
      residuals function, see description below.
:param deriv:
       derivatives function, see description below.
:param modfunct:
      model function, see description below.
:param ...:
      other parameters each corresponding with one of the attributes
      described below.
      
**Function parameters:**


**Attributes:**

**Method:**

.. automethod:: fit(params0=None)
"""

   cdef mp_par *c_pars
   cdef int m, npar, dictarg
   cdef double *c_inverr, *c_yvals, *xall
   cdef mp_config *config
   cdef mp_result *result
   cdef object params_t, parms0
   cdef object modfunct, xvals, yvals, errvals, inverr, pars
   cdef object resfunct, resargs
   cdef object deriv, dflags
   cdef object deviates
   cdef readonly object message

   def __cinit__(self):
      self.config = <mp_config*>calloc(1, sizeof(mp_config))
      self.result = <mp_result*>calloc(1, sizeof(mp_result))
      
   def __dealloc__(self):
      free(self.config)
      free(self.result.resid)
      free(self.result.xerror)
      free(self.result.covar)
      free(self.result)
      free(self.c_pars)
      free(self.xall)
      
   def __init__(self, resfunct=None, deriv=None, modfunct=None, params0=None,
                parinfo=None, xvalues=None, yvalues=None, errors=None,
                ftol=None, xtol=None, gtol=None, epsfcn=None,
                stepfactor=None, covtol=None, maxiter=None, maxfev=None,
                resargs={}):
      if modfunct is not None and resfunct is not None:
         raise ValueError('cannot specify both model- and residuals functions')
      if resargs is not None and resargs is None:
         raise ValueError('resargs meaningless without residuals function')
      self.npar = 0
      self.m = 0
      self.modfunct = modfunct                  # model function
      self.resfunct = resfunct                  # residuals function
      self.deriv = deriv
      self.params0 = params0                    # fitting parameters
      self.xvalues = xvalues
      self.yvalues = yvalues
      self.errors = errors
      self.parinfo = parinfo                    # parameter constraints
      self.ftol = ftol
      self.xtol = xtol
      self.gtol = gtol
      self.epsfcn = epsfcn
      self.stepfactor = stepfactor
      self.covtol = covtol
      self.maxiter = maxiter
      self.maxfev = maxfev
      self.resargs = resargs                    # args to residuals function
      self.dictarg = isinstance(resargs, dict)  # keyword args or one object?

   property params0:
      def __get__(self):
         return self.parms0
      def __set__(self, value):
         self.params = value
         self.parms0 = value
   
   property params:
      def __get__(self):
         cdef npy_intp* shape = [self.npar]
         value = PyArray_SimpleNewFromData(1, shape, NPY_DOUBLE, self.xall)
         if self.params_t is not None:
            return self.params_t(value)
         else:
            return value
      def __set__(self, value):
         if value is None:
            return
         cdef int i, l
         cdef double *xall
         if not isinstance(value, numpy.ndarray):
            self.params_t = type(value)
            l = len(value)
         else:
            l = value.size
         if self.npar==0:
            self.npar = l
         elif l!=self.npar:
            self.message = 'inconsistent parameter array size'
            raise ValueError(self.message)
         xall = <double*>calloc(self.npar, sizeof(double))
         for i in range(self.npar):
            xall[i] = value[i]
         free(self.xall)
         self.xall = xall
         if self.dflags is None:
            self.dflags = [False]*self.npar              # flags for deriv()
         if self.deriv is not None and self.pars is None:
            self.parinfo = [{'side': 3}]*self.npar

   property xvalues:
      def __get__(self):
         return self.xvals
      def __set__(self, value):
         if value is None:
            return
         if self.modfunct is None:
            self.message = 'xvalues meaningless without model function'
            raise ValueError(self.message)
         if self.m!=0:
            if value.size!=self.m:
               self.message = 'inconsistent xvalues array size'
               raise ValueError(self.message)
         else:
            self.m = value.size
         self.xvals = value
    
   property yvalues:
      def __get__(self):
         return self.yvals
      def __set__(self, value):
         if value is None:
            return
         if self.modfunct is None:
            self.message = 'yvalues meaningless without model function'
            raise ValueError(self.message)
         if self.m!=0:
            if value.size!=self.m:
               self.message = 'inconsistent yvalues array size'
               raise ValueError(self.message)
         else:
            self.m = value.size
         if not value.dtype=='d':
            value = value.astype('f8')
         if not value.flags.contiguous and value.flags.aligned:
            value = value.copy()
         self.yvals = value
         self.c_yvals = <double*>PyArray_DATA(value)

   property errors:
      def __get__(self):
         return self.errvals
      def __set__(self, value):
         if value is None:
            return
         if self.modfunct is None:
            self.message = 'errors meaningless without model function'
            raise ValueError(self.message)
         if self.m!=0:
            if value.size!=self.m:
               self.message = 'inconsistent errors array size'
               raise ValueError(self.message)
         else:
            self.m = value.size
         self.errvals = value
         self.inverr = 1./value
         self.c_inverr = <double*>PyArray_DATA(self.inverr)
         
   property parinfo:
      def __get__(self):
         return self.pars
      def __set__(self, value):
         if value is None:
            return
         cdef mp_par *c_par
         l = len(value)
         if self.npar==0:
            self.npar = l
         elif l!=self.npar:
            self.message = 'inconsistent parinfo list length'
            raise ValueError(self.message)
         self.pars = value
         if self.c_pars==NULL:
            self.c_pars = <mp_par*>calloc(self.npar, sizeof(mp_par))
         ipar = 0         
         for par in self.pars:
            if par is not None:
               c_par = &self.c_pars[ipar]

               try:
                  c_par.fixed = par['fixed']
               except:
                  c_par.fixed = 0

               try:
                  limits = par['limits']
                  for limit in (0,1):
                     if limits[limit] is not None:
                        c_par.limited[limit] = 1
                        c_par.limits[limit] = limits[limit]
               except:
                  for limit in (0,1):
                     c_par.limited[limit] = 0
                     c_par.limits[limit] = 0.0
               
               try:
                  c_par.step = par['step']
               except:
                  c_par.step = 0
                  
               try:
                  c_par.side = par['side']
               except:
                  c_par.side = 0

               try:
                  c_par.deriv_debug = par['deriv_debug']
               except:
                  c_par.deriv_debug = 0

            ipar += 1
      def __del__(self):
         free(self.c_pars)
         self.c_pars = NULL

   property ftol:
      def __get__(self):
         return self.config.ftol
      def __set__(self, value):
         if value is not None:
            self.config.ftol = value
      def __del__(self):
         self.config.ftol = 0.0

   property xtol:
      def __get__(self):
         return self.config.xtol
      def __set__(self, value):
         if value is not None:
            self.config.xtol = value
      def __del__(self):
         self.config.xtol = 0.0

   property gtol:
      def __get__(self):
         return self.config.gtol
      def __set__(self, value):
         if value is not None:
            self.config.gtol = value
      def __del__(self):
         self.config.gtol = 0.0

   property epsfcn:
      def __get__(self):
         return self.config.epsfcn
      def __set__(self, value):
         if value is not None:
            self.config.epsfcn = value
      def __del__(self):
         self.config.epsfcn = 0.0

   property stepfactor:
      def __get__(self):
         return self.config.stepfactor
      def __set__(self, value):
         if value is not None:
            self.config.stepfactor = value
      def __del__(self):
         self.config.stepfactor = 0.0

   property covtol:
      def __get__(self):
         return self.config.covtol
      def __set__(self, value):
         if value is not None:
            self.config.covtol = value
      def __del__(self):
         self.config.covtol = 0.0

   property maxiter:
      def __get__(self):
         return self.config.maxiter
      def __set__(self, value):
         if value is not None:
            self.config.maxiter = value
      def __del__(self):
         self.config.maxiter = 0

   property maxfev:
      def __get__(self):
         return self.config.maxfev
      def __set__(self, value):
         if value is not None:
            self.config.maxfev = value
      def __del__(self):
         self.config.maxfev = 0

   property chi2_min:
      def __get__(self):
         return self.result.bestnorm

   property orignorm:
      def __get__(self):
         return self.result.orignorm
         
   property niter:
      def __get__(self):
         return self.result.niter

   property nfev:
      def __get__(self):
         return self.result.nfev

   property status:
      def __get__(self):
         return self.result.status

   property nfree:
      def __get__(self):
         return self.result.nfree

   property npegged:
      def __get__(self):
         return self.result.npegged
         
   property version:
      def __get__(self):
         return self.result.version

   property covar:
      def __get__(self):
         cdef npy_intp* shape = [self.npar, self.npar]
         value = PyArray_SimpleNewFromData(2, shape, NPY_DOUBLE,
                                           self.result.covar)
         return numpy.matrix(value)

   property resid:
      def __get__(self):
         cdef npy_intp* shape = [self.m]
         value = PyArray_SimpleNewFromData(1, shape, NPY_DOUBLE,
                                           self.result.resid)
         return value
 
   property xerror:
      def __get__(self):
         cdef npy_intp* shape = [self.npar]
         value = PyArray_SimpleNewFromData(1, shape, NPY_DOUBLE,
                                           self.result.xerror)
         return value

   property dof:
      def __get__(self):
         return self.m - self.nfree

   property rchi2_min:
      def __get__(self):
         return self.chi2_min/self.dof
         
   property stderr:
      def __get__(self):
         return numpy.sqrt(numpy.diagonal(self.covar)*self.rchi2_min) 

   cdef allocres(self):
      # allocate arrays in mp_result_struct
      self.result.resid = <double*>calloc(self.m, sizeof(double))
      self.result.xerror = <double*>calloc(self.npar, sizeof(double))
      self.result.covar = <double*>calloc(self.npar*self.npar, sizeof(double))

   def fit(self, params0=None):
      """
:param params0:
   initial fitting parameters. Default: previous initial values are used.
"""
      cdef mp_par *parinfo
      if params0 is not None:
         self.params0 = params0
      else:
         self.params = self.params0
      status = mpfit(<mp_func>xmpfunc, self.npar, self.xall,
                     self.c_pars, self.config, <void*>self, self.result)
      if status<=0:
         if status in MP_ERR:
            self.message = 'mpfit error: %s (%d)' % (MP_ERR[status], status)
         else:
            self.message = 'mpfit error, status=%d' % status
         raise RuntimeError(self.message)
      
      if status in MP_OK:
         self.message = 'mpfit (potential) success: %s (%d)' % \
                                                    (MP_OK[status], status)
      else:
         self.message = None
      return status

   def __call__(self, yvalues=None, xvalues=None, params0=None):
      self.yvalues = yvalues
      self.xvalues = xvalues
      self.fit(params0)
      return self.params