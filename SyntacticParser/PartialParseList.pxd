from ParseTree.ParseNode cimport ParseNode
from ProbabilisticContextFreeGrammar.ProbabilisticParseNode cimport ProbabilisticParseNode

cdef class PartialParseList:

    cdef list __partial_parses

    cpdef addPartialParse(self, ParseNode node)

    cpdef updatePartialParse(self, ProbabilisticParseNode parse_node)

    cpdef ParseNode getPartialParse(self, int index)

    cpdef int size(self)
