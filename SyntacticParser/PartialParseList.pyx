from ParseTree.ParseNode cimport ParseNode

cdef class PartialParseList:

    def __init__(self):
        """
        Constructor for the PartialParseList class. Initializes partial parses array list.
        """
        self.__partial_parses = []

    cpdef addPartialParse(self, ParseNode node):
        """
        Adds a new partial parse (actually a parse node representing the root of the subtree of the partial parse)
        :param node: Root of the subtree showing the partial parse.
        """
        self.__partial_parses.append(node)

    cpdef updatePartialParse(self, ProbabilisticParseNode parse_node):
        """
        Updates the partial parse by removing less probable nodes with the given parse node.
        :param parse_node: Parse node to be added to the partial parse.
        """
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
        """
        Accessor for the partialParses array list.
        :param index: Position of the parse node.
        :return: Parse node at the given position.
        """
        return self.__partial_parses[index]

    cpdef int size(self):
        """
        Returns size of the partial parse.
        :return: Size of the partial parse.
        """
        return len(self.__partial_parses)
