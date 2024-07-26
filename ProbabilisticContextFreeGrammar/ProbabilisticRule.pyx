from ParseTree.Symbol cimport Symbol
from ContextFreeGrammar.RuleType import RuleType

cdef class ProbabilisticRule(Rule):

    cpdef constructor6(self, str rule):
        """
        Constructor for any probabilistic rule from a string. The string is of the form X -> .... [probability] The
        method constructs left hand side symbol and right hand side symbol(s) from the input string.
        :param rule: String containing the rule. The string is of the form X -> .... [probability]
        """
        cdef str prob, left, right
        cdef list rightSide
        cdef int i
        prob = rule[rule.find("[") + 1:rule.find("]")].strip()
        left = rule[0:rule.find("->")].strip()
        right = rule[rule.find("->") + 2:rule.find("[")].strip()
        self.left_hand_side = Symbol(left)
        rightSide = right.split(" ")
        self.right_hand_side = []
        for i in range(0, len(rightSide)):
            self.right_hand_side.append(Symbol(rightSide[i]))
        self.__probability = float(prob)
        self.__count = 0

    def __init__(self,
                 param1: Symbol | str = None,
                 param2: list[Symbol] = None,
                 param3: RuleType = None,
                 param4: float = None):
        super().__init__()
        self.__count = 0
        self.__probability = 0.0
        if isinstance(param1, Symbol) and param3 is None:
            super().__init__(param1, param2)
        elif isinstance(param1, Symbol) and param3 is not None:
            super().__init__(param1, param2, param3)
            self.__probability = param4
        elif isinstance(param1, str):
            self.constructor6(param1)

    cpdef float getProbability(self):
        """
        Accessor for the probability attribute.
        :return: Probability attribute.
        """
        return self.__probability

    cpdef increment(self):
        """
        Increments the count attribute.
        """
        self.__count = self.__count + 1

    cpdef normalizeProbability(self, int total):
        """
        Calculates the probability from count and the given total value.
        :param total: Value used for calculating the probability.
        """
        self.__probability = self.__count / total

    cpdef int getCount(self):
        """
        Accessor for the count attribute.
        :return: Count attribute.
        """
        return self.__count

    def __str__(self) -> str:
        """
        Converts the rule to the form X -> ... [probability]
        :return: String form of the rule in the form of X -> ... [probability]
        """
        return super().__str__() + "[" + str(self.__probability) + "]"
