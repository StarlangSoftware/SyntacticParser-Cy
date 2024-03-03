from enum import Enum, auto


class RuleType(Enum):
    TERMINAL = auto
    SINGLE_NON_TERMINAL = auto
    TWO_NON_TERMINAL = auto
    MULTIPLE_NON_TERMINAL = auto
