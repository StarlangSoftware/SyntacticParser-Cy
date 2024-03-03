from ParseTree.ParseNode cimport ParseNode

cdef class PartialParseList:

    def __init__(self):
        self.__partial_parses = []

    cpdef addPartialParse(self, ParseNode node):
        self.__partial_parses.append(node)

    cpdef updatePartialParse(self, ProbabilisticParseNode parse_node):
        cdef bint found
        cdef int i
        cdef ParseNode partial_parse
        found = False
        for i in range(0, len(self.__partial_parses)):
            partial_parse = self.__partial_parses[i]
            if partial_parse.getData().getName() == parse_node.getData().getName():
                if isinstance(partial_parse, ProbabilisticParseNode):
                    if partial_parse.getLogProbability() < parse_node.getLogProbability():
                        self.__partial_parses.pop(i)
                        self.__partial_parses.append(parse_node)
                found = True
                break
        if not found:
            self.__partial_parses.append(parse_node)

    cpdef ParseNode getPartialParse(self, int index):
        return self.__partial_parses[index]

    cpdef int size(self):
        return len(self.__partial_parses)
