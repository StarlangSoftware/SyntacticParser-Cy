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
        """
        Empty constructor for the ContextFreeGrammar class.
        """
        self.min_count = 1
        self.rules = []
        self.rules_right_sorted = []
        self.dictionary = CounterHashMap()

    cpdef constructor2(self, str rule_file_name, str dictionary_file_name, int min_count):
        """
        Constructor for the ContextFreeGrammar class. Reads the rules from the rule file, lexicon rules from the
        dictionary file and sets the minimum frequency parameter.
        :param rule_file_name: File name for the rule file.
        :param dictionary_file_name: File name for the lexicon file.
        :param min_count: Minimum frequency parameter.
        """
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
        """
        Another constructor for the ContextFreeGrammar class. Constructs the lexicon from the leaf nodes of the trees
        in the given treebank. Extracts rules from the non-leaf nodes of the trees in the given treebank. Also sets the
        minimum frequency parameter.
        :param tree_bank: Treebank containing the constituency trees.
        :param min_count: Minimum frequency parameter.
        """
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
        """
        Compares two rules based on their left sides lexicographically.
        :param ruleA: the first rule to be compared.
        :param ruleB: the second rule to be compared.
        :return: -1 if the first rule is less than the second rule lexicographically, 1 if the first rule is larger than
                  the second rule lexicographically, 0 if they are the same rule.
        """
        if ruleA.left_hand_side.name < ruleB.left_hand_side.name:
            return -1
        elif ruleA.left_hand_side.name > ruleB.left_hand_side.name:
            return 1
        else:
            return 0

    @staticmethod
    def ruleRightComparator(ruleA: Rule, ruleB: Rule) -> int:
        """
        Compares two rules based on their right sides lexicographically.
        :param ruleA: the first rule to be compared.
        :param ruleB: the second rule to be compared.
        :return: -1 if the first rule is less than the second rule lexicographically, 1 if the first rule is larger than
                  the second rule lexicographically, 0 if they are the same rule.
        """
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
        """
        Compares two rules based on first their left hand side and their right hand side lexicographically.
        :param ruleA: the first rule to be compared.
        :param ruleB: the second rule to be compared.
        :return: -1 if the first rule is less than the second rule lexicographically, 1 if the first rule is larger than
        the second rule lexicographically, 0 if they are the same rule.
        """
        if ruleA.left_hand_side == ruleB.left_hand_side:
            return ContextFreeGrammar.ruleRightComparator(ruleA, ruleB)
        else:
            return ContextFreeGrammar.ruleLeftComparator(ruleA, ruleB)

    cpdef readDictionary(self, str dictionary_file_name):
        """
        Reads the lexicon for the grammar. Each line consists of two items, the terminal symbol and the frequency of
        that symbol. The method fills the dictionary counter hash map according to this data.
        :param dictionary_file_name: File name of the lexicon.
        """
        cdef str line
        cdef list items
        input_file = open(dictionary_file_name, "r", encoding="utf8")
        lines = input_file.readlines()
        for line in lines:
            items = line.split(" ")
            self.dictionary.putNTimes(items[0], int(items[1]))
        input_file.close()

    cpdef updateTypes(self):
        """
        Updates the types of the rules according to the number of symbols on the right hand side. Rule type is TERMINAL
        if the rule is like X -> a, SINGLE_NON_TERMINAL if the rule is like X -> Y, TWO_NON_TERMINAL if the rule is like
        X -> YZ, MULTIPLE_NON_TERMINAL if the rule is like X -> YZT...
        """
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
        """
        Constructs the lexicon from the given treebank. Reads each tree and for each leaf node in each tree puts the
        symbol in the dictionary.
        :param tree_bank: Treebank containing the constituency trees.
        """
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
        """
        Updates the exceptional symbols of the leaf nodes in the trees. Constituency trees consists of rare symbols and
        numbers, which are usually useless in creating constituency grammars. This is due to the fact that, numbers may
        not occur exactly the same both in the train and/or test set, although they have the same meaning in general.
        Similarly, when a symbol occurs in the test set but not in the training set, there will not be any rule covering
        that symbol and therefore no parse tree will be generated. For those reasons, the leaf nodes containing numerals
        are converted to the same terminal symbol, i.e. _num_; the leaf nodes containing rare symbols are converted to
        the same terminal symbol, i.e. _rare_.
        :param parse_tree: Parse tree to be updated.
        :param min_count:Minimum frequency for the terminal symbols to be considered as rare.
        """
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
        """
        Updates the exceptional words in the sentences for which constituency parse trees will be generated. Constituency
        trees consist of rare symbols and numbers, which are usually useless in creating constituency grammars. This is
        due to the fact that, numbers may not occur exactly the same both in the train and/or test set, although they have
        the same meaning in general. Similarly, when a symbol occurs in the test set but not in the training set, there
        will not be any rule covering that symbol and therefore no parse tree will be generated. For those reasons, the
        words containing numerals are converted to the same terminal symbol, i.e. _num_; thewords containing rare symbols
        are converted to the same terminal symbol, i.e. _rare_.
        :param sentence: Sentence to be updated.
        """
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
        """
        After constructing the constituency tree with a parser for a sentence, it contains exceptional words such as
        rare words and numbers, which are represented as _rare_ and _num_ symbols in the tree. Those words should be
        converted to their original forms. This method replaces the exceptional symbols to their original forms by
        replacing _rare_ and _num_ symbols.
        :param parse_tree: Parse tree to be updated.
        :param sentence: Original sentence for which constituency tree is generated.
        """
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
        """
        Converts a parse node in a tree to a rule. The symbol in the parse node will be the symbol on the leaf side of the
        rule, the symbols in the child nodes will be the symbols on the right hand side of the rule.
        :param parse_node: Parse node for which a rule will be created.
        :param trim: If true, the tags will be trimmed. If the symbol's data contains '-' or '=', this method trims all
                     characters after those characters.
        :return: A new rule constructed from a parse node and its children.
        """
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
        """
        Recursive method to generate all rules from a subtree rooted at the given node.
        :param parse_node: Root node of the subtree.
        """
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
        """
        Inserts a new rule into the correct position in the sorted rules and rulesRightSorted array lists.
        :param new_rule: Rule to be inserted into the sorted array lists.
        """
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
        """
        Removes a given rule from the sorted rules and rulesRightSorted array lists.
        :param rule: Rule to be removed from the sorted array lists.
        """
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
        """
        Returns rules formed as X -> ... Since there can be more than one rule, which have X on the left side, the method
        first binary searches the rule to obtain the position of such a rule, then goes up and down to obtain others
        having X on the left side.
        :param X: Left side of the rule
        :return: Rules of the form X -> ...
        """
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
        """
        Returns all symbols X from terminal rules such as X -> a.
        :return: All symbols X from terminal rules such as X -> a.
        """
        cdef list result
        cdef Rule rule
        result = []
        for rule in self.rules:
            if rule.type == RuleType.TERMINAL and rule.left_hand_side not in result:
                result.append(rule.left_hand_side)
        return result

    cpdef list getLeftSide(self):
        """
        Returns all symbols X from all rules such as X -> ...
        :return: All symbols X from all rules such as X -> ...
        """
        cdef list result
        cdef Rule rule
        result = []
        for rule in self.rules:
            if rule.left_hand_side not in result:
                result.append(rule.left_hand_side)
        return result

    cpdef list getTerminalRulesWithRightSideX(self, Symbol S):
        """
        Returns all rules with the given terminal symbol on the right hand side, that is it returns all terminal rules
        such as X -> s
        :param S: Terminal symbol on the right hand side.
        :return: All rules with the given terminal symbol on the right hand side
        """
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
        """
        Returns all rules with the given non-terminal symbol on the right hand side, that is it returns all non-terminal
        rules such as X -> S
        :param S: Non-terminal symbol on the right hand side.
        :return: All rules with the given non-terminal symbol on the right hand side
        """
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
        """
        Returns all rules with the given two non-terminal symbols on the right hand side, that is it returns all
        non-terminal rules such as X -> AB.
        :param A: First non-terminal symbol on the right hand side.
        :param B: Second non-terminal symbol on the right hand side.
        :return: All rules with the given two non-terminal symbols on the right hand side
        """
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
        """
        Returns the symbol on the right side of the first rule with one non-terminal symbol on the right hand side, that
        is it returns S of the first rule such as X -> S. S should also not be in the given removed list.
        :param removed_list: Discarded list for symbol S.
        :return: The symbol on the right side of the first rule with one non-terminal symbol on the right hand side. The
        symbol to be returned should also not be in the given discarded list.
        """
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
        """
        Returns all rules with more than two non-terminal symbols on the right hand side, that is it returns all
        non-terminal rules such as X -> ABC...
        :return: All rules with more than two non-terminal symbols on the right hand side.
        """
        cdef Symbol remove_candidate
        cdef Rule rule
        remove_candidate = None
        for rule in self.rules:
            if rule.type == RuleType.MULTIPLE_NON_TERMINAL:
                remove_candidate = rule
                break
        return remove_candidate

    cpdef removeSingleNonTerminalFromRightHandSide(self):
        """
        In conversion to Chomsky Normal Form, rules like X -> Y are removed and new rules for every rule as Y -> beta are
        replaced with X -> beta. The method first identifies all X -> Y rules. For every such rule, all rules Y -> beta
        are identified. For every such rule, the method adds a new rule X -> beta. Every Y -> beta rule is then deleted.
        """
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
        """
        In conversion to Chomsky Normal Form, rules like A -> BC... are replaced with A -> X1... and X1 -> BC. This
        method replaces B and C non-terminals on the right hand side with X1 for all rules in the grammar.
        :param first: Non-terminal symbol B.
        :param second: Non-terminal symbol C.
        :param _with: Non-terminal symbol X1.
        """
        cdef Rule rule
        for rule in self.rules:
            if rule.type == RuleType.MULTIPLE_NON_TERMINAL:
                rule.updateMultipleNonTerminal(first, second, _with)

    cpdef updateMultipleNonTerminalFromRightHandSide(self):
        """
        In conversion to Chomsky Normal Form, rules like A -> BC... are replaced with A -> X1... and X1 -> BC. This
        method determines such rules and for every such rule, it adds new rule X1->BC and updates rule A->BC to A->X1.
        """
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
        """
        The method converts the grammar into Chomsky normal form. First, rules like X -> Y are removed and new rules for
        every rule as Y -> beta are replaced with X -> beta. Second, rules like A -> BC... are replaced with A -> X1...
        and X1 -> BC.
        """
        self.removeSingleNonTerminalFromRightHandSide()
        self.updateMultipleNonTerminalFromRightHandSide()
        self.rules.sort(key=cmp_to_key(self.ruleComparator))
        self.rules_right_sorted.sort(key=cmp_to_key(self.ruleRightComparator))

    cpdef Rule searchRule(self, Rule rule):
        """
        Searches a given rule in the grammar.
        :param rule: Rule to be searched.
        :return: Rule if found, null otherwise.
        """
        cdef int pos
        pos = self.binarySearch(self.rules, rule, self.ruleComparator)
        if pos >= 0:
            return self.rules[pos]
        else:
            return None

    cpdef int size(self):
        """
        Returns number of rules in the grammar.
        :return: Number of rules in the Context Free Grammar.
        """
        return len(self.rules)
