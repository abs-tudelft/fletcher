# Copyright 2018 Delft University of Technology
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""This package contains a base class for objects with key-value configuration
keys. The class contains some error checking and convenience methods."""

__all__ = ["Configurable"]


class Configurable(object):
    """An object with a key-value configuration associated with it."""
    
    def __init__(self, **config):
        super().__init__()
        self._config = {}
        for key, value in config.items():
            setattr(self, key, value)
    
    @property
    def _config_defaults(self):
        """Returns a map from config key name to default value and type."""
        return {}
    
    def get_cfg(self, name):
        """Returns the configuration value for the given key."""
        
        # Return config key.
        val = self._config.get(name, None)
        if val is not None:
            return val
        
        # Return config key default.
        val = self._config_defaults.get(name, None)
        if val is not None:
            return val
        
        raise KeyError(name)
    
    def get_cfg_dict(self, subset=None):
        """Gets a subset of the configuration as a map. subset can be one of
        the following:
         - None: all keys are returned.
         - set(): only the keys which are in set() are returned.
         - dict(): only the keys which also exist in dict() are returned, but
           the returned key will be the value of the dict().
        """
        if subset is None:
            mapping = {key: key for key in self._config_defaults.keys()}
        elif isinstance(subset, set):
            mapping = {key: key for key in subset}
        elif isinstance(subset, dict):
            mapping = subset
        else:
            raise TypeError()
        
        return {key_returned: self.get_cfg(key_here) for key_here, key_returned in mapping.items()}
    
    def __getattr__(self, name):
        """__getattr__ override to allow direct access to config keys."""
        try:
            return self.get_cfg(name)
        except KeyError:
            raise AttributeError("%s (%s)" % (name, self.__class__))
    
    def __setattr__(self, name, value):
        """__setattr__ override to allow direct access to config keys."""
        
        # Handle assignments to config keys.
        default = self._config_defaults.get(name, None)
        if default is not None:
            
            # Check config key type.
            if isinstance(default, bool):
                value = bool(value)
            elif isinstance(default, int):
                value = int(value)
                if value < 0:
                    raise ValueError("Negative integers are not supported for parameters")
            elif isinstance(default, str):
                value = str(value)
            else:
                raise TypeError()
            
            # Remove the entry if it is the default value, otherwise
            # add/update it.
            if value == default:
                if name in self._config:
                    del self._config[name]
            else:
                self._config[name] = value
            
            return
        
        # Defer to object.
        super().__setattr__(name, value)
    
    def _params(self):
        """Returns a list of parameters that get added to the __str__
        representation of this field."""
        return ["%s=%s" % x for x in self._config.items()]
        
    def __str__(self):
        return "%s(%s)" % (self.__class__.__name__, ", ".join(self._params()))
    
    __repr__ = __str__
