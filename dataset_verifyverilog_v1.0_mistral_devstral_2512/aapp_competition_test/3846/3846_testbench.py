import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
N = 5  # Number of participants (scaled down)
M = 8  # Maximum events (scaled down)
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def pack_event_ids(event_ids, element_bits=4):
    """Pack list of event IDs into a single integer."""
    result = 0
    for i, val in enumerate(event_ids):
        result |= (val & ((1 << element_bits) - 1)) << (i * element_bits)
    return result

def pack_event_types(event_types):
    """Pack list of event types into a bit vector."""
    result = 0
    for i, val in enumerate(event_types):
        if val == '-':
            result |= (1 << i)
    return result

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_leader_determination(dut):
    """Test the leader determination module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (n, m, events, expected_output)
    test_cases = [
        (5, 4, [('+', 1), ('+', 2), ('-', 2), ('-', 1)], {1, 3, 4, 5}),
        (3, 2, [('+', 1), ('-', 2)], {3}),
        (2, 4, [('+', 1), ('-', 1), ('+', 2), ('-', 2)], set()),
        (5, 6, [('+', 1), ('-', 1), ('-', 3), ('+', 3), ('+', 4), ('-', 4)], {2, 3, 5}),
        (2, 4, [('+', 1), ('-', 2), ('+', 2), ('-', 1)], set()),
    ]
    
    for test_idx, (n, m, events, expected) in enumerate(test_cases):
        dut._log.info(f"Running test case {test_idx+1}: {n} participants, {m} events")
        
        # Prepare input arrays
        event_types = []
        event_ids = []
        for op, id_val in events:
            event_types.append(op)
            event_ids.append(id_val)
        
        # Pad to M events if needed
        while len(event_types) < M:
            event_types.append('+')  # Default
            event_ids.append(1)      # Default
        
        # Pack inputs
        packed_types = pack_event_types(event_types[:M])
        packed_ids = pack_event_ids(event_ids[:M])
        
        # Set inputs
        dut.event_type.value = packed_types
        dut.event_id.value = packed_ids
        
        # Wait for done
        cycles = 0
        while not (is_value_defined(dut.done.value) and int(dut.done.value) == 1):
            await RisingEdge(dut.clk)
            cycles += 1
            if cycles > MAX_CYCLES:
                raise TestFailure(f"Timeout in test case {test_idx+1}")
        
        # Read result
        if not is_value_defined(dut.possible_leaders.value):
            raise TestFailure(f"Output undefined in test case {test_idx+1}")
        
        result_bits = int(dut.possible_leaders.value)
        
        # Extract actual result
        actual = set()
        for i in range(n):
            if result_bits & (1 << i):
                actual.add(i+1)
        
        # Verify
        if actual != expected:
            raise TestFailure(
                f"Test case {test_idx+1} failed:\n"
                f"  Expected: {sorted(expected) if expected else 'empty'}\n"
                f"  Got: {sorted(actual) if actual else 'empty'}"
            )
        
        dut._log.info(f"Test case {test_idx+1} passed")
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info("All tests passed!")