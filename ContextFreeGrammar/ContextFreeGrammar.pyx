from functools import cmp_to_key
import re

from Corpus.Sentence cimport Sentence
from DataStructure.CounterHashMap cimport CounterHashMap
from Dictionary.Word cimport Word
from ParseTree.NodeCollector cimport NodeCollector
from ParseTree.NodeCondition.IsLeaf cimport IsLeaf
from ParseTree.ParseNode cimport ParseNode
from ParseTree.ParseTree cimport ParseTree
from ParseTree.Symbol cimport Symbol
from ParseTree.TreeBank cimport TreeBank

from ContextFreeGrammar.RuleType import RuleType

cdef class ContextFreeGrammar:

    cpdef constructor1(self):
        self.min_count = 1
        self.rules = []
        self.rules_right_sorted = []
        self.dictionary = CounterHashMap()

    cpdef constructor2(self, str rule_file_name, str dictionary_file_name, int min_count):
        cdef str line
        cdef Rule new_rule
        self.rules = []
        self.rules_right_sorted = []
        self.dictionary = CounterHashMap()
        input_file = open(rule_file_name, "r", encoding="utf8")
        lines = input_file.readlines()
        for line in lines:
            new_rule = Rule(line)
            self.rules.append(new_rule)
            self.rules_right_sorted.append(new_rule)
        input_file.close()
        self.rules.sort(key=cmp_to_key(self.ruleComparator))
        self.rules_right_sorted.sort(key=cmp_to_key(self.ruleRightComparator))
        self.readDictionary(dictionary_file_name)
        self.updateTypes()
        self.min_count = min_count

    cpdef constructor3(self, TreeBank tree_bank, int min_count):
        cdef int i
        cdef ParseTree parse_tree
        self.rules = []
        self.rules_right_sorted = []
        self.dictionary = CounterHashMap()
        self.constructDictionary(tree_bank)
        for i in range(0, tree_bank.size()):
            parse_tree = tree_bank.get(i)
            self.updateTree(parse_tree, min_count)
            self.addRules(parse_tree.getRoot())
        self.updateTypes()
        self.min_count = min_count

    def __init__(self,
                 param1: str | TreeBank = None,
                 param2: str | int = None,
                 param3: int = None):
        self.rules = []
        self.rules_right_sorted = []
        self.dictionary = CounterHashMap()
        if param1 is None:
            self.constructor1()
        elif isinstance(param1, str) and isinstance(param2, str):
            self.constructor2(param1, param2, param3)
        elif isinstance(param1, TreeBank) and isinstance(param2, int):
            self.constructor3(param1, param2)

    @staticmethod
    def ruleLeftComparator(ruleA: Rule, ruleB: Rule) -> int:
        if ruleA.left_hand_side.name < ruleB.left_hand_side.name:
            return -1
        elif ruleA.left_hand_side.name > ruleB.left_hand_side.name:
            return 1
        else:
            return 0

    @staticmethod
    def ruleRightComparator(ruleA: Rule, ruleB: Rule) -> int:
        i = 0
        while i < len(ruleA.right_hand_side) and i < len(ruleB.right_hand_side):
            if ruleA.right_hand_side[i] == ruleB.right_hand_side[i]:
                i = i + 1
            else:
                if ruleA.right_hand_side[i].name < ruleB.right_hand_side[i].name:
                    return -1
                elif ruleA.right_hand_side[i].name > ruleB.right_hand_side[i].name:
                    return 1
                else:
                    return 0
        if len(ruleA.right_hand_side) < len(ruleB.right_hand_side):
            return -1
        elif len(ruleA.right_hand_side) > len(ruleB.right_hand_side):
            return 1
        else:
            return 0

    @staticmethod
    def ruleComparator(ruleA: Rule, ruleB: Rule) -> int:
        if ruleA.left_hand_side == ruleB.left_hand_side:
            return ContextFreeGrammar.ruleRightComparator(ruleA, ruleB)
        else:
            return ContextFreeGrammar.ruleLeftComparator(ruleA, ruleB)

    cpdef readDictionary(self, str dictionary_file_name):
        cdef str line
        cdef list items
        input_file = open(dictionary_file_name, "r", encoding="utf8")
        lines = input_file.readlines()
        for line in lines:
            items = line.split(" ")
            self.dictionary.putNTimes(items[0], int(items[1]))
        input_file.close()

    cpdef updateTypes(self):
        cdef set nonTerminals
        cdef Rule rule
        nonTerminals = set()
        for rule in self.rules:
            nonTerminals.add(rule.left_hand_side.getName())
        for rule in self.rules:
            if len(rule.right_hand_side) > 2:
                rule.type = RuleType.MULTIPLE_NON_TERMINAL
            elif len(rule.right_hand_side) == 2:
                rule.type = RuleType.TWO_NON_TERMINAL
            elif rule.right_hand_side[0].isTerminal() or \
                    Word.isPunctuationSymbol(rule.right_hand_side[0].getName()) or \
                    rule.right_hand_side[0].getName() not in nonTerminals:
                rule.type = RuleType.TERMINAL
            else:
                rule.type = RuleType.SINGLE_NON_TERMINAL

    cpdef constructDictionary(self, TreeBank tree_bank):
        cdef int i
        cdef ParseTree parse_tree
        cdef list leaf_list
        cdef ParseNode parse_node
        cdef NodeCollector node_collector
        for i in range(0, tree_bank.size()):
            parse_tree = tree_bank.get(i)
            node_collector = NodeCollector(parse_tree.getRoot(), IsLeaf())
            leaf_list = node_collector.collect()
            for parse_node in leaf_list:
                self.dictionary.put(parse_node.getData().getName())

    cpdef updateTree(self, ParseTree parse_tree, int min_count):
        cdef NodeCollector nodeCollector
        cdef list leaf_list
        cdef ParseNode parse_node
        cdef str data
        nodeCollector = NodeCollector(parse_tree.getRoot(), IsLeaf())
        leaf_list = nodeCollector.collect()
        pattern1 = re.compile("\\+?\\d+")
        pattern2 = re.compile("\\+?(\\d+)?\\.\\d*")
        for parse_node in leaf_list:
            data = parse_node.getData().getName()
            if pattern1.fullmatch(data) or (pattern2.fullmatch(data) and data != "."):
                parse_node.setData(Symbol("_num_"))
            elif self.dictionary.count(data) < min_count:
                parse_node.setData(Symbol("_rare_"))

    cpdef removeExceptionalWordsFromSentence(self, Sentence sentence):
        cdef int i
        cdef Word word
        pattern1 = re.compile("\\+?\\d+")
        pattern2 = re.compile("\\+?(\\d+)?\\.\\d*")
        for i in range(0, sentence.wordCount()):
            word = sentence.getWord(i)
            if pattern1.fullmatch(word.getName()) or (pattern2.fullmatch(word.getName()) and word.getName() != "."):
                word.setName("_num_")
            elif self.dictionary.count(word.getName()) < self.min_count:
                word.setName("_rare_")

    cpdef reinsertExceptionalWordsFromSentence(self, ParseTree parse_tree, Sentence sentence):
        cdef NodeCollector nodeCollector
        cdef list leaf_list
        cdef int i
        cdef str tree_word, sentence_word
        nodeCollector = NodeCollector(parse_tree.getRoot(), IsLeaf())
        leaf_list = nodeCollector.collect()
        for i in range(0, len(leaf_list)):
            tree_word = leaf_list[i].getData().getName()
            sentence_word = sentence.getWord(i).getName()
            if tree_word == "_rare_" or tree_word == "_num_":
                leaf_list[i].setData(Symbol(sentence_word))

    @staticmethod
    def toRule(parse_node: ParseNode, trim: bool) -> Rule:
        right = []
        if trim:
            left = parse_node.getData().trimSymbol()
        else:
            left = parse_node.getData()
        for i in range(0, parse_node.numberOfChildren()):
            child_node = parse_node.getChild(i)
            if child_node.getData() is not None:
                if child_node.getData().isTerminal() or not trim:
                    right.append(child_node.getData())
                else:
                    right.append(child_node.getData().trimSymbol())
            else:
                return None
        return Rule(left, right)

    cpdef addRules(self, ParseNode parse_node):
        cdef Rule new_rule
        cdef int i
        cdef ParseNode child_node
        new_rule = ContextFreeGrammar.toRule(parse_node, True)
        if new_rule is not None:
            self.addRule(new_rule)
        for i in range(0, parse_node.numberOfChildren()):
            child_node = parse_node.getChild(i)
            if child_node.numberOfChildren() > 0:
                self.addRules(child_node)

    cpdef int binarySearch(self, list rules, Rule rule, comparator):
        cdef int lo, hi, mid
        lo = 0
        hi = len(rules) - 1
        while lo <= hi:
            mid = (lo + hi) // 2
            if comparator(rules[mid], rule) == 0:
                return mid
            if comparator(rules[mid], rule) <= 0:
                lo = mid + 1
            else:
                hi = mid - 1
        return -(lo + 1)

    cpdef addRule(self, Rule new_rule):
        cdef int pos
        pos = self.binarySearch(self.rules, new_rule, self.ruleComparator)
        if pos < 0:
            self.rules.insert(-pos - 1, new_rule)
            pos = self.binarySearch(self.rules_right_sorted, new_rule, self.ruleRightComparator)
            if pos >= 0:
                self.rules_right_sorted.insert(pos, new_rule)
            else:
                self.rules_right_sorted.insert(-pos - 1, new_rule)

    cpdef removeRule(self, Rule rule):
        cdef int pos, pos_up, pos_down
        pos = self.binarySearch(self.rules, rule, self.ruleComparator)
        if pos >= 0:
            self.rules.pop(pos)
            pos = self.binarySearch(self.rules_right_sorted, rule, self.ruleRightComparator)
            pos_up = pos
            while pos_up >= 0 and self.ruleRightComparator(self.rules_right_sorted[pos_up], rule) == 0:
                if self.ruleComparator(rule, self.rules_right_sorted[pos_up]) == 0:
                    self.rules_right_sorted.pop(pos_up)
                    return
                pos_up = pos_up - 1
            pos_down = pos + 1
            while pos_down < len(self.rules_right_sorted) \
                    and self.ruleRightComparator(self.rules_right_sorted[pos_down], rule) == 0:
                if self.ruleComparator(rule, self.rules_right_sorted[pos_down]) == 0:
                    self.rules_right_sorted.pop(pos_down)
                    return
                pos_down = pos_down + 1

    cpdef list getRulesWithLeftSideX(self, Symbol X):
        cdef list result
        cdef Rule dummy_rule
        cdef int middle, middle_up, middle_down
        result = []
        dummy_rule = Rule(X, X)
        middle = self.binarySearch(self.rules, dummy_rule, self.ruleLeftComparator)
        if middle >= 0:
            middle_up = middle
            while middle_up >= 0 and self.rules[middle_up].left_hand_side.getName() == X.getName():
                result.append(self.rules[middle_up])
                middle_up = middle_up - 1
            middle_down = middle + 1
            while middle_down < len(self.rules) and self.rules[middle_down].left_hand_side.getName() == X.getName():
                result.append(self.rules[middle_down])
                middle_down = middle_down + 1
        return result

    cpdef list partOfSpeechTags(self):
        cdef list result
        cdef Rule rule
        result = []
        for rule in self.rules:
            if rule.type == RuleType.TERMINAL and rule.left_hand_side not in result:
                result.append(rule.left_hand_side)
        return result

    cpdef list getLeftSide(self):
        cdef list result
        cdef Rule rule
        result = []
        for rule in self.rules:
            if rule.left_hand_side not in result:
                result.append(rule.left_hand_side)
        return result

    cpdef list getTerminalRulesWithRightSideX(self, Symbol S):
        cdef list result
        cdef Rule dummy_rule
        cdef int middle, middle_up, middle_down
        result = []
        dummy_rule = Rule(S, S)
        middle = self.binarySearch(self.rules_right_sorted, dummy_rule, self.ruleRightComparator)
        if middle >= 0:
            middle_up = middle
            while middle_up >= 0 and self.rules_right_sorted[middle_up].right_hand_side[0].getName() == S.getName():
                if self.rules_right_sorted[middle_up].type == RuleType.TERMINAL:
                    result.append(self.rules_right_sorted[middle_up])
                middle_up = middle_up - 1
            middle_down = middle + 1
            while middle_down < len(self.rules_right_sorted) and \
                    self.rules_right_sorted[middle_down].right_hand_side[0].getName() == S.getName():
                if self.rules_right_sorted[middle_down].type == RuleType.TERMINAL:
                    result.append(self.rules_right_sorted[middle_down])
                middle_down = middle_down + 1
        return result

    cpdef list getRulesWithRightSideX(self, Symbol S):
        cdef list result
        cdef Rule dummy_rule
        cdef int pos, pos_up, pos_down
        result = []
        dummy_rule = Rule(S, S)
        pos = self.binarySearch(self.rules_right_sorted, dummy_rule, self.ruleRightComparator)
        if pos >= 0:
            pos_up = pos
            while pos_up >= 0 and \
                    self.rules_right_sorted[pos_up].right_hand_side[0].getName() == S.getName() and \
                    len(self.rules_right_sorted[pos_up].right_hand_side) == 1:
                result.append(self.rules_right_sorted[pos_up])
                pos_up = pos_up - 1
            pos_down = pos + 1
            while pos_down < len(self.rules_right_sorted) and \
                    self.rules_right_sorted[pos_down].right_hand_side[0].getName() == S.getName() and \
                    len(self.rules_right_sorted[pos_down].right_hand_side) == 1:
                result.append(self.rules_right_sorted[pos_down])
                pos_down = pos_down + 1
        return result

    cpdef list getRulesWithTwoNonTerminalsOnRightSide(self, Symbol A, Symbol B):
        cdef list result
        cdef Rule dummy_rule
        cdef int pos, pos_up, pos_down
        result = []
        dummy_rule = Rule(A, A, B)
        pos = self.binarySearch(self.rules_right_sorted, dummy_rule, self.ruleRightComparator)
        if pos >= 0:
            pos_up = pos
            while pos_up >= 0 and \
                    self.rules_right_sorted[pos_up].right_hand_side[0].getName() == A.getName() and \
                    self.rules_right_sorted[pos_up].right_hand_side[1].getName() == B.getName() and \
                    len(self.rules_right_sorted[pos_up].right_hand_side) == 2:
                result.append(self.rules_right_sorted[pos_up])
                pos_up = pos_up - 1
            pos_down = pos + 1
            while pos_down < len(self.rules_right_sorted) and \
                    self.rules_right_sorted[pos_down].right_hand_side[0].getName() == A.getName() and \
                    self.rules_right_sorted[pos_down].right_hand_side[1].getName() == B.getName() and \
                    len(self.rules_right_sorted[pos_down].right_hand_side) == 2:
                result.append(self.rules_right_sorted[pos_down])
                pos_down = pos_down + 1
        return result

    cpdef Symbol getSingleNonTerminalCandidateToRemove(self, list removed_list):
        cdef Symbol remove_candidate
        cdef Rule rule
        remove_candidate = None
        for rule in self.rules:
            if rule.type == RuleType.SINGLE_NON_TERMINAL and \
                    not rule.leftRecursive() and \
                    rule.right_hand_side[0] not in removed_list:
                remove_candidate = rule.right_hand_side[0]
                break
        return remove_candidate

    cpdef Rule getMultipleNonTerminalCandidateToUpdate(self):
        cdef Symbol remove_candidate
        cdef Rule rule
        remove_candidate = None
        for rule in self.rules:
            if rule.type == RuleType.MULTIPLE_NON_TERMINAL:
                remove_candidate = rule
                break
        return remove_candidate

    cpdef removeSingleNonTerminalFromRightHandSide(self):
        cdef list non_terminal_list, rule_list, candidate_list, clone
        cdef Symbol remove_candidate, symbol
        cdef Rule rule, candidate
        non_terminal_list = []
        remove_candidate = self.getSingleNonTerminalCandidateToRemove(non_terminal_list)
        while remove_candidate is not None:
            rule_list = self.getRulesWithRightSideX(remove_candidate)
            for rule in rule_list:
                candidate_list = self.getRulesWithLeftSideX(remove_candidate)
                for candidate in candidate_list:
                    clone = []
                    for symbol in candidate.right_hand_side:
                        clone.append(symbol)
                    self.addRule(Rule(rule.left_hand_side, clone, candidate.type))
                self.removeRule(rule)
            non_terminal_list.append(remove_candidate)
            remove_candidate = self.getSingleNonTerminalCandidateToRemove(non_terminal_list)

    cpdef updateAllMultipleNonTerminalWithNewRule(self, Symbol first, Symbol second, Symbol _with):
        cdef Rule rule
        for rule in self.rules:
            if rule.type == RuleType.MULTIPLE_NON_TERMINAL:
                rule.updateMultipleNonTerminal(first, second, _with)

    cpdef updateMultipleNonTerminalFromRightHandSide(self):
        cdef int new_variable_count
        cdef Rule update_candidate
        cdef list new_right_hand_side
        cdef Symbol new_symbol
        new_variable_count = 0
        update_candidate = self.getMultipleNonTerminalCandidateToUpdate()
        while update_candidate is not None:
            new_right_hand_side = []
            new_symbol = Symbol("X" + str(new_variable_count))
            new_right_hand_side.append(update_candidate.right_hand_side[0])
            new_right_hand_side.append(update_candidate.right_hand_side[1])
            self.updateAllMultipleNonTerminalWithNewRule(update_candidate.right_hand_side[0], update_candidate.right_hand_side[1], new_symbol)
            self.addRule(Rule(new_symbol, new_right_hand_side, RuleType.TWO_NON_TERMINAL))
            update_candidate = self.getMultipleNonTerminalCandidateToUpdate()
            new_variable_count = new_variable_count + 1

    cpdef convertToChomskyNormalForm(self):
        self.removeSingleNonTerminalFromRightHandSide()
        self.updateMultipleNonTerminalFromRightHandSide()
        self.rules.sort(key=cmp_to_key(self.ruleComparator))
        self.rules_right_sorted.sort(key=cmp_to_key(self.ruleRightComparator))

    cpdef Rule searchRule(self, Rule rule):
        cdef int pos
        pos = self.binarySearch(self.rules, rule, self.ruleComparator)
        if pos >= 0:
            return self.rules[pos]
        else:
            return None

    cpdef int size(self):
        return len(self.rules)
