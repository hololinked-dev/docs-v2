# OOP For Thing

It is intuitive to think or abstract a physical device as a class (as-)in object-oriented programming. A good amount of code base exists in open source within scientific community that uses OOP to model physical devices, such as:

- [pymeasure](https://github.com/pymeasure/pymeasure)
- [pylablib](https://github.com/AlexShkarin/pyLabLib)
- [CALA public](https://gitlab.lrz.de/cala-public)
- Implementations of individual device drivers one may find in GitHub repositories.

Interactions with a device can be segregated into properties, actions and events and operations on these interactions (for example, `readProperty`, `invokeAction`, `subscribeEvent`). See W3C WoT for an elaborate theory - [Homepage](https://www.w3.org/WoT/). Such interactions can be described in a JSON format in a [WoT Thing Description](https://www.w3.org/TR/wot-thing-description/).  

Within python's class API, properties can be easily implemented with the `@property` decorator/`property` object and actions can be implemented as methods. Say a DC power supply has a voltage property that reads and writes voltage value and an action to turn the power supply ON or OFF:

```python
class DCPowerSupply(Thing):

    @property
    def voltage(self) -> float:
        """Get or set the voltage of the power supply."""
        # self._voltage = ...
        return self._voltage # placeholder for actual device interaction

    @voltage.setter
    def voltage(self, value: float):
        if not (0 <= value <= 30):
            raise ValueError("Voltage must be between 0 and 30V")
        # write code here to set the voltage on the device
        self._voltage = value # placeholder for actual device interaction

    def toggle_power(self, state: bool) -> None:
        """Turn the power supply on or off."""
        if state:
            print("Power supply turned ON") # placeholder
        else:
            print("Power supply turned OFF") # placeholder
        # add logic here to turn the power supply on or off
```

Events may be supported by reactive programming libraries or pub-sub messaging.

This simplistic approach will be used as a starting point to create the object API as it is easy to understand and has a low barrier to entry. But it needs to be extended to be more robust and flexible.


## Descriptors for Interaction Affordances

A superset of the above code with signifcantly added functionality can be implmented using the descriptor protocol in python. Descriptor protocols are the machinery behind:

- `@property` decorators, validated object attributes ([`param`](https://param.holoviz.org/), [`traitlets`](https://traitlets.readthedocs.io/en/stable/), [`attrs`](https://www.attrs.org/en/stable/) etc.)
- python bound methods, `@classmethod`, `@staticmethod`
- ORMs for database packages like `SQLAlchemy`, `Django ORM`, `Tortoise ORM` where SQL statements are auto generated

Accessing an interaction affordace gives the following behaviour:

| Affordance | Class Level Access      | Instance Level Access | Descriptor Object Purpose                              |
|------------|-------------------------|-----------------------|--------------------------------------------------------|
| Properties | `Property` object       | `Property` value      | holds `Property` metadata and performs get, set & delete |
| Actions    | unbound `Action` object | bound `Action`        | holds `Action` metadata and implements `__call__` with payload validation |
| Events     | `Event` object          | event publisher       | holds `Event` metadata and handles generation of `EventPublisher` |

The same DC power supply example can be rewritten using descriptors as follows:

```python
class DCPowerSupply(Thing):
    
    voltage = Property(model=float, default=0.0, min=0, max=30, observable=True,
        description="Voltage set point of the power supply.")

    @voltage.setter
    def set_voltage(self, value: float) -> None:
        """Set the voltage of the power supply."""
        self._voltage = value  # placeholder for actual device interaction

    @voltage.getter
    def get_voltage(self) -> float:
        """Get the voltage of the power supply."""
        return self._voltage  # placeholder

    @action(input_schema={"type": "boolean", "description": "State of the power supply"})
    def toggle_power(self, state: bool) -> None:
        """Turn the power supply on or off."""
        if state:
            print("Power supply turned ON") # placeholder
        else:
            print("Power supply turned OFF") # placeholder
        self.power_state_event.publish(state=state)

    power_state_event = Event(
        description="Event published when the power state changes.",
        schema={"type": "object", "properties": {"state": {"type": "boolean"}}}
    )
```

This allows using the same affordance object in different contexts, for example with a `Property` such as:

- Accessing a property at the class level to get metadata like default value, schema, observability etc.
- Access at the instance level to get the current value.
- `Thing` class can autogenerate Thing models using the affordance objects, whereas protocols can add forms to autogenerate Thing Descriptions.
- `ThingModel`s can generate Thing objects by mapping it to descriptors easily for an API first approach.


=== "instance level access"

    ```python
    device = DCPowerSupply()
    # Accessing the property value
    print(device.voltage)  
    # Setting the property value
    device.voltage = 12.0  
    print(device.voltage)  
    # Calling the action
    device.toggle_power(True)  
    ```

=== "object level access"

    The interaction affordances can also accessed in the exact same fashion internally within the object:

    ```python hl_lines="13 16 18 23"

    class DCPowerSupply(Thing):

        @action(input_schema=...)
        def sweep_and_turn_off(
            self, 
            start_voltage: float,
            end_voltage: float,
            step: float = 0.1,
            per_voltage_period: float = 0.1
        ) -> None:
            """Do a voltage ramp and turn off the power supply."""
            # Accessing the property with dot operator
            self.voltage = start_voltage  
            print(f"Sweeping voltage from {start_voltage}V to {end_voltage}V \
                with period {per_voltage_period}s")
            while self.voltage < end_voltage:
                # write property 
                self.voltage += step  # Increment voltage
                # read property
                print(f"Voltage set to {self.voltage}V")
                time.sleep(per_voltage_period)  # Simulate time delay
            # invoke action to turn off the power supply
            self.toggle_power(False)  
            # automatically publishes the turn off event
    ```


The metadata may be accessed as follows:

=== "Property"

    ```python
    print(DCPowerSupply.voltage.readonly) # False
    print(DCPowerSupply.voltage.observable) # True
    print(DCPowerSupply.voltage.to_affordance()) # TD fragment for property for Thing Model
    ```
    ```json
    {
        "voltage": {
            "title": "voltage",
            "description": "voltage set point of the power supply.",
            "type": "number",
            "minimum": 0,
            "maximum": 30,
            "readOnly": false,
            "observable": true
        }
    }
    ```

=== "Action"

    ```python
    print(DCPowerSupply.toggle_power.to_affordance()) # TD fragment for action for Thing Model
    ```
    ```json
    {
        "toggle_power": {
            "title": "toggle_power",
            "type": "object",
            "description": "Turn the power supply on or off.",
            "properties": {
                "state": {
                    "type": "boolean",
                    "description": "State of the power supply"
                }
            },
            "required": ["state"]
        }
    }
    ```

=== "Event"

    ```python
    print(DCPowerSupply.power_state_event.schema)  # Accessing the event schema
    ```
    ```json
    {
        "type": "object",
        "properties": {
            "state": {
                "type": "boolean"
            }
        }
    }
    ```
  
## Event Descriptors

API possibilities:

- defining event schema using JSON schema or pydantic models
- pub-sub model
- generate Thing Model fragment

Sequence of access:

1. Serialize the event payload
2. Simply push the payload to the publishing socket











