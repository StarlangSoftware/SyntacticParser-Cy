from ParseTree.ParseNode cimport ParseNode
from ParseTree.ParseTree cimport ParseTree
from ParseTree.TreeBank cimport TreeBank

from ContextFreeGrammar.ContextFreeGrammar cimport ContextFreeGrammar

cdef class ProbabilisticContextFreeGrammar(ContextFreeGrammar):

    cpdef constructor2(self, str rule_file_name, str dictionary_file_name, int min_count)

    cpdef constructor3(self, TreeBank tree_bank, int min_count)

    cpdef addRules(self, ParseNode parse_node)

    cpdef float probabilityOfParseNode(self, ParseNode parse_node)

    cpdef float probabilityOfParseTree(self, ParseTree parse_tree)

    cpdef removeSingleNonTerminalFromRightHandSide(self)

    cpdef updateMultipleNonTerminalFromRightHandSide(self)

    cpdef convertToChomskyNormalForm(self)
