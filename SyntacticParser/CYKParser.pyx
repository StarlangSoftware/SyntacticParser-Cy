from Corpus.Sentence cimport Sentence
from Dictionary.Word cimport Word
from ParseTree.ParseNode cimport ParseNode
from ParseTree.ParseTree cimport ParseTree
from ParseTree.Symbol cimport Symbol

from ContextFreeGrammar.Rule cimport Rule
from SyntacticParser.PartialParseList cimport PartialParseList

cdef class CYKParser:

    cpdef list parse(self, ContextFreeGrammar cfg, Sentence sentence):
        cdef list parse_trees, candidates
        cdef Sentence back_up
        cdef list table
        cdef int i, j, k, x, y
        cdef Rule candidate
        cdef ParseNode left_node, right_node
        cdef ParseTree parse_tree
        parse_trees = []
        back_up = Sentence()
        for i in range(0, sentence.wordCount()):
            back_up.addWord(Word(sentence.getWord(i).getName()))
        cfg.removeExceptionalWordsFromSentence(sentence)
        table = []
        for i in range(0, sentence.wordCount()):
            table.append([])
            for j in range(i, sentence.wordCount()):
                table[i].append(PartialParseList())
        for i in range(0, sentence.wordCount()):
            candidates = cfg.getTerminalRulesWithRightSideX(Symbol(sentence.getWord(i).getName()))
            for candidate in candidates:
                table[i][i].addPartialParse(ParseNode(ParseNode(Symbol(sentence.getWord(i).getName())), candidate.left_hand_side))
        for j in range(1, sentence.wordCount()):
            for i in range(j - 1, -1, -1):
                for k in range(i, j):
                    for x in range(0, table[i][k].size()):
                        for y in range(0, table[k + 1][j].size()):
                            left_node = table[i][k].getPartialParse(x)
                            right_node = table[k + 1][j].getPartialParse(y)
                            candidates = cfg.getRulesWithTwoNonTerminalsOnRightSide(left_node.getData(), right_node.getData())
                            for candidate in candidates:
                                table[i][j].addPartialParse(ParseNode(left_node, right_node, candidate.left_hand_side))
        for i in range(0, table[0][sentence.wordCount() - 1].size()):
            if table[0][sentence.wordCount() - 1].getPartialParse(i).getData().getName() == "S":
                parse_tree = ParseTree(table[0][sentence.wordCount() - 1].getPartialParse(i))
                parse_tree.correctParents()
                parse_tree.removeXNodes()
                parse_trees.append(parse_tree)
        for parse_tree in parse_trees:
            cfg.reinsertExceptionalWordsFromSentence(parse_tree, back_up)
        return parse_trees
