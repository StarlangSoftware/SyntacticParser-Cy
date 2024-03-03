from ParseTree.Symbol cimport Symbol

cdef class Rule:

    cdef Symbol left_hand_side
    cdef list right_hand_side
    cdef object type

    cpdef constructor1(self)
    cpdef constructor2(self, Symbol left_hand_side, Symbol right_hand_side)
    cpdef constructor3(self,
                     Symbol left_hand_side,
                     Symbol right_hand_side_symbol_1,
                     Symbol right_hand_side_symbol_2)

    cpdef constructor4(self, Symbol left_hand_side, list right_hand_side)

    cpdef constructor5(self, Symbol left_hand_side, list right_hand_side, object _type)

    cpdef constructor6(self, str rule)

    cpdef bint leftRecursive(self)

    cpdef bint updateMultipleNonTerminal(self, Symbol first, Symbol second, Symbol _with)