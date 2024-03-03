from Corpus.Sentence cimport Sentence
from DataStructure.CounterHashMap cimport CounterHashMap
from ParseTree.ParseNode cimport ParseNode
from ParseTree.ParseTree cimport ParseTree
from ParseTree.Symbol cimport Symbol
from ParseTree.TreeBank cimport TreeBank
from ContextFreeGrammar.Rule cimport Rule

cdef class ContextFreeGrammar:

    cdef CounterHashMap dictionary
    cdef list rules
    cdef list rules_right_sorted
    cdef int min_count

    cpdef constructor1(self)

    cpdef constructor2(self, str rule_file_name, str dictionary_file_name, int min_count)

    cpdef constructor3(self, TreeBank tree_bank, int min_count)

    cpdef readDictionary(self, str dictionary_file_name)

    cpdef updateTypes(self)

    cpdef constructDictionary(self, TreeBank tree_bank)

    cpdef updateTree(self, ParseTree parse_tree, int min_count)

    cpdef removeExceptionalWordsFromSentence(self, Sentence sentence)

    cpdef reinsertExceptionalWordsFromSentence(self, ParseTree parse_tree, Sentence sentence)

    cpdef addRules(self, ParseNode parse_node)

    cpdef int binarySearch(self, list rules, Rule rule, comparator)

    cpdef addRule(self, Rule new_rule)

    cpdef removeRule(self, Rule rule)

    cpdef list getRulesWithLeftSideX(self, Symbol X)

    cpdef list partOfSpeechTags(self)

    cpdef list getLeftSide(self)

    cpdef list getTerminalRulesWithRightSideX(self, Symbol S)

    cpdef list getRulesWithRightSideX(self, Symbol S)

    cpdef list getRulesWithTwoNonTerminalsOnRightSide(self, Symbol A, Symbol B)

    cpdef Symbol getSingleNonTerminalCandidateToRemove(self, list removed_list)

    cpdef Rule getMultipleNonTerminalCandidateToUpdate(self)

    cpdef removeSingleNonTerminalFromRightHandSide(self)

    cpdef updateAllMultipleNonTerminalWithNewRule(self, Symbol first, Symbol second, Symbol _with)

    cpdef updateMultipleNonTerminalFromRightHandSide(self)

    cpdef convertToChomskyNormalForm(self)

    cpdef Rule searchRule(self, Rule rule)

    cpdef int size(self)
