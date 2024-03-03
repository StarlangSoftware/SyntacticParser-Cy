from math import log

from Corpus.Sentence cimport Sentence
from Dictionary.Word cimport Word
from ParseTree.ParseNode cimport ParseNode
from ParseTree.ParseTree cimport ParseTree
from ParseTree.Symbol cimport Symbol
from ProbabilisticContextFreeGrammar.ProbabilisticParseNode cimport ProbabilisticParseNode
from ProbabilisticContextFreeGrammar.ProbabilisticRule cimport ProbabilisticRule
from SyntacticParser.PartialParseList cimport PartialParseList

cdef class ProbabilisticCYKParser:
    cpdef list parse(self, ProbabilisticContextFreeGrammar pcfg, Sentence sentence):
        cdef list parse_trees, candidates
        cdef Sentence back_up
        cdef list table
        cdef int i, j, k, x, y
        cdef ProbabilisticRule candidate
        cdef ParseNode left_node, right_node
        cdef ParseTree parse_tree
        parse_trees = []
        back_up = Sentence()
        for i in range(0, sentence.wordCount()):
            back_up.addWord(Word(sentence.getWord(i).getName()))
        pcfg.removeExceptionalWordsFromSentence(sentence)
        table = []
        for i in range(0, sentence.wordCount()):
            table.append([])
            for j in range(i, sentence.wordCount()):
                table[i].append(PartialParseList())
        for i in range(0, sentence.wordCount()):
            candidates = pcfg.getTerminalRulesWithRightSideX(Symbol(sentence.getWord(i).getName()))
            for candidate in candidates:
                if isinstance(candidate, ProbabilisticRule):
                    table[i][i].addPartialParse(
                        ProbabilisticParseNode(ParseNode(Symbol(sentence.getWord(i).getName())),
                                               candidate.left_hand_side, log(candidate.getProbability())))
        for j in range(1, sentence.wordCount()):
            for i in range(j - 1, -1, -1):
                for k in range(i, j):
                    for x in range(0, table[i][k].size()):
                        for y in range(0, table[k + 1][j].size()):
                            left_node = table[i][k].getPartialParse(x)
                            right_node = table[k + 1][j].getPartialParse(y)
                            if isinstance(left_node, ProbabilisticParseNode) and isinstance(right_node,
                                                                                            ProbabilisticParseNode):
                                candidates = pcfg.getRulesWithTwoNonTerminalsOnRightSide(left_node.getData(),
                                                                                         right_node.getData())
                                for candidate in candidates:
                                    if isinstance(candidate, ProbabilisticRule):
                                        probability = log(
                                            candidate.getProbability()) + left_node.getLogProbability() + right_node.getLogProbability()
                                        table[i][j].updatePartialParse(
                                            ProbabilisticParseNode(left_node, right_node, candidate.left_hand_side,
                                                                   probability))
        best_probability = -1
        for i in range(0, table[0][sentence.wordCount() - 1].size()):
            parse_node = table[0][sentence.wordCount() - 1].getPartialParse(i)
            if isinstance(parse_node, ProbabilisticParseNode):
                if parse_node.getData().getName() == "S" and parse_node.getLogProbability() > best_probability:
                    best_probability = parse_node.getLogProbability()
        for i in range(0, table[0][sentence.wordCount() - 1].size()):
            parse_node = table[0][sentence.wordCount() - 1].getPartialParse(i)
            if isinstance(parse_node, ProbabilisticParseNode):
                if parse_node.getData().getName() == "S" and parse_node.getLogProbability() == best_probability:
                    parse_tree = ParseTree(parse_node)
                    parse_tree.correctParents()
                    parse_tree.removeXNodes()
                    parse_trees.append(parse_tree)
        for parse_tree in parse_trees:
            pcfg.reinsertExceptionalWordsFromSentence(parse_tree, back_up)
        return parse_trees
