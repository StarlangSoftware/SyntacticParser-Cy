from ParseTree.ParseNode cimport ParseNode
from ParseTree.Symbol cimport Symbol

cdef class ProbabilisticParseNode(ParseNode):

    def __init__(self,
                 param1: ParseNode | Symbol,
                 param2: ParseNode | Symbol | float,
                 param3: Symbol | float = None,
                 param4: float = None):
        if param4 is not None:
            super().__init__(param1, param2, param3)
            self.__log_probability = param4
        elif param3 is not None and isinstance(param3, int):
            super().__init__(param1, param2)
            self.__log_probability = param3
        elif isinstance(param2, int):
            super().__init__(param1)
            self.__log_probability = param2

    cpdef float getLogProbability(self):
        return self.__log_probability
