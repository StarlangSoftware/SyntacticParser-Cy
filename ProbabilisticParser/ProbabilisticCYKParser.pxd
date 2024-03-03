from Corpus.Sentence cimport Sentence
from ProbabilisticContextFreeGrammar.ProbabilisticContextFreeGrammar cimport ProbabilisticContextFreeGrammar

cdef class ProbabilisticCYKParser:

    cpdef list parse(self, ProbabilisticContextFreeGrammar pcfg, Sentence sentence)
