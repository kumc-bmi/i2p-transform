# Stubs for luigi.parameter (Python 3.5)
#
# NOTE: This dynamically typed stub was automatically generated by stubgen.

from json.encoder import JSONEncoder
from typing import Any, Optional
from collections import Mapping

class ParameterException(Exception): ...
class MissingParameterException(ParameterException): ...
class UnknownParameterException(ParameterException): ...
class DuplicateParameterException(ParameterException): ...

class Parameter:
    significant = ...  # type: Any
    positional = ...  # type: Any
    description = ...  # type: Any
    always_in_help = ...  # type: Any
    def __init__(self, default: Any = ..., is_global: bool = ..., significant: bool = ..., description: Optional[Any] = ..., config_path: Optional[Any] = ..., positional: bool = ..., always_in_help: bool = ..., batch_method: Optional[Any] = ...) -> None: ...
    def has_task_value(self, task_name, param_name): ...
    def task_value(self, task_name, param_name): ...
    def parse(self, x): ...
    def serialize(self, x): ...
    def normalize(self, x): ...
    def next_in_enumeration(self, _value): ...

class _DateParameterBase(Parameter):
    interval = ...  # type: Any
    start = ...  # type: Any
    def __init__(self, interval: int = ..., start: Optional[Any] = ..., **kwargs) -> None: ...
    def date_format(self): ...
    def parse(self, s): ...
    def serialize(self, dt): ...

class DateParameter(_DateParameterBase):
    date_format = ...  # type: str
    def next_in_enumeration(self, value): ...
    def normalize(self, value): ...

class MonthParameter(DateParameter):
    date_format = ...  # type: str
    def next_in_enumeration(self, value): ...
    def normalize(self, value): ...

class YearParameter(DateParameter):
    date_format = ...  # type: str
    def next_in_enumeration(self, value): ...
    def normalize(self, value): ...

class _DatetimeParameterBase(Parameter):
    interval = ...  # type: Any
    start = ...  # type: Any
    def __init__(self, interval: int = ..., start: Optional[Any] = ..., **kwargs) -> None: ...
    def date_format(self): ...
    def parse(self, s): ...
    def serialize(self, dt): ...
    def normalize(self, dt): ...
    def next_in_enumeration(self, value): ...

class DateHourParameter(_DatetimeParameterBase):
    date_format = ...  # type: str

class DateMinuteParameter(_DatetimeParameterBase):
    date_format = ...  # type: str
    deprecated_date_format = ...  # type: str
    def parse(self, s): ...

class DateSecondParameter(_DatetimeParameterBase):
    date_format = ...  # type: str

class IntParameter(Parameter):
    def parse(self, s): ...
    def next_in_enumeration(self, value): ...

class FloatParameter(Parameter):
    def parse(self, s): ...

class BoolParameter(Parameter):
    def __init__(self, *args, **kwargs) -> None: ...
    def parse(self, s): ...
    def normalize(self, value): ...

class DateIntervalParameter(Parameter):
    def parse(self, s): ...

class TimeDeltaParameter(Parameter):
    def parse(self, input): ...
    def serialize(self, x): ...

class TaskParameter(Parameter):
    def parse(self, input): ...
    def serialize(self, cls): ...

class EnumParameter(Parameter):
    def __init__(self, *args, **kwargs) -> None: ...
    def parse(self, s): ...
    def serialize(self, e): ...

class FrozenOrderedDict(Mapping):
    def __init__(self, *args, **kwargs) -> None: ...
    def __getitem__(self, key): ...
    def __iter__(self): ...
    def __len__(self): ...
    def __hash__(self): ...
    def get_wrapped(self): ...

class DictParameter(Parameter):
    class DictParamEncoder(JSONEncoder):
        def default(self, obj): ...
    def normalize(self, value): ...
    def parse(self, s): ...
    def serialize(self, x): ...

class ListParameter(Parameter):
    def normalize(self, x): ...
    def parse(self, x): ...
    def serialize(self, x): ...

class TupleParameter(Parameter):
    def parse(self, x): ...
    def serialize(self, x): ...

class NumericalParameter(Parameter):
    description = ...  # type: str
    def __init__(self, left_op: Any = ..., right_op: Any = ..., *args, **kwargs) -> None: ...
    def parse(self, s): ...

class ChoiceParameter(Parameter):
    description = ...  # type: str
    def __init__(self, var_type: Any = ..., *args, **kwargs) -> None: ...
    def parse(self, s): ...
