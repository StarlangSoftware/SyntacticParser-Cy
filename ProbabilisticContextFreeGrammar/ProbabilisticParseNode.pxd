from ParseTree.ParseNode cimport ParseNode

cdef class ProbabilisticParseNode(ParseNode):

    cdef float __log_probability

    cpdef float getLogProbability(self)
