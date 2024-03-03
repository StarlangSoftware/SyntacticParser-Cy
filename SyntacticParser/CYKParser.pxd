from Corpus.Sentence cimport Sentence
from ContextFreeGrammar.ContextFreeGrammar cimport ContextFreeGrammar

cdef class CYKParser:

    cpdef list parse(self, ContextFreeGrammar cfg, Sentence sentence)
