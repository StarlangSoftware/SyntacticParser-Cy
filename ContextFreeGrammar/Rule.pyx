from ParseTree.Symbol cimport Symbol

from ContextFreeGrammar.RuleType import RuleType

cdef class Rule:

    cpdef constructor1(self):
        self.right_hand_side = []

    cpdef constructor2(self, Symbol left_hand_side, Symbol right_hand_side):
        self.left_hand_side = left_hand_side
        self.right_hand_side = []
        self.right_hand_side.append(right_hand_side)

    cpdef constructor3(self,
                     Symbol left_hand_side,
                     Symbol right_hand_side_symbol_1,
                     Symbol right_hand_side_symbol_2):
        self.constructor2(left_hand_side, right_hand_side_symbol_1)
        self.right_hand_side.append(right_hand_side_symbol_2)

    cpdef constructor4(self, Symbol left_hand_side, list right_hand_side):
        self.left_hand_side = left_hand_side
        self.right_hand_side = right_hand_side

    cpdef constructor5(self,
                     Symbol left_hand_side,
                     list right_hand_side,
                     object _type):
        self.constructor4(left_hand_side, right_hand_side)
        self.type = _type

    cpdef constructor6(self, str rule):
        cdef str left, right
        cdef list right_side
        left = rule[0:rule.find("->")].strip()
        right = rule[rule.find("->") + 2:].strip()
        self.left_hand_side = Symbol(left)
        right_side = right.split(" ")
        self.right_hand_side = []
        for i in range(0, len(right_side)):
            self.right_hand_side.append(Symbol(right_side[i]))

    def __init__(self,
                 param1: Symbol | str = None,
                 param2: Symbol | list = None,
                 param3: Symbol | RuleType = None):
        if param1 is None:
            self.constructor1()
        elif isinstance(param1, Symbol) and isinstance(param2, Symbol) and param3 is None:
            self.constructor2(param1, param2)
        elif isinstance(param1, Symbol) and isinstance(param2, Symbol) and isinstance(param3, Symbol):
            self.constructor3(param1, param2, param3)
        elif isinstance(param1, Symbol) and isinstance(param2, list) and param3 is None:
            self.constructor4(param1, param2)
        elif isinstance(param1, Symbol) and isinstance(param2, list) and isinstance(param3, RuleType):
            self.constructor5(param1, param2, param3)
        elif isinstance(param1, str):
            self.constructor6(param1)

    cpdef bint leftRecursive(self):
        return self.right_hand_side[0] == self.left_hand_side and self.type == RuleType.SINGLE_NON_TERMINAL

    cpdef bint updateMultipleNonTerminal(self,
                                  Symbol first,
                                  Symbol second,
                                  Symbol _with):
        cdef int i
        for i in range(0, len(self.right_hand_side) - 1):
            if self.right_hand_side[i] == first and self.right_hand_side[i + 1] == second:
                self.right_hand_side.pop(i + 1)
                self.right_hand_side.pop(i)
                self.right_hand_side.insert(i, _with)
                if len(self.right_hand_side) == 2:
                    self.type = RuleType.TWO_NON_TERMINAL
                return True
        return False

    def __str__(self):
        result = self.left_hand_side.name + "->"
        for symbol in self.right_hand_side:
            result += " " + symbol.name
        return result
