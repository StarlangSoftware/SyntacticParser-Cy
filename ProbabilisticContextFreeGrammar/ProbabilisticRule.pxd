from ContextFreeGrammar.Rule cimport Rule

cdef class ProbabilisticRule(Rule):

    cdef float __probability
    cdef int __count

    cpdef constructor6(self, str rule)

    cpdef float getProbability(self)

    cpdef increment(self)

    cpdef normalizeProbability(self, int total)

    cpdef int getCount(self)
