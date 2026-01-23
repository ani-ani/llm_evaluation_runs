import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 4
ARRAY_SIZE_A = 16
ARRAY_SIZE_B = 8
MAX_POSITIONS = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

async def write_array(dut, prefix, values, size, width):
    """Write values to array using individual ports."""
    for i in range(size):
        port_name = f"{prefix}{i}"
        if has_signal(dut, port_name):
            val = values[i] if i < len(values) else 0
            getattr(dut, port_name).value = clamp_to_width(val, width)
        else:
            raise TestFailure(f"Port {port_name} not found")

async def read_positions(dut, count):
    """Read positions from output."""
    positions = []
    for i in range(MAX_POSITIONS):
        port_name = f"pos{i}"
        if has_signal(dut, port_name):
            val = getattr(dut, port_name).value
            if is_value_defined(val):
                int_val = int(val)
                if i < count:
                    positions.append(int_val)
        else:
            break
    return positions

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_find_positions(dut):
    """Test the find_positions module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Test cases: (n, m, p, a_list, b_list, expected_positions)
    test_cases = [
        (5, 3, 1, [1, 2, 3, 2, 1], [1, 2, 3], [1, 3]),
        (6, 3, 2, [1, 3, 2, 2, 3, 1], [1, 2, 3], [1, 2]),
        (5, 3, 1, [1, 2, 3, 2, 1], [1, 2, 3], [1, 3]),
        (3, 2, 1, [1, 1, 1], [1, 1], [1, 2]),
        (4, 2, 2, [1, 2, 3, 4], [2, 4], [2]),
    ]
    
    for i, (n, m, p, a_list, b_list, expected) in enumerate(test_cases):
        dut._log.info(f"Running test case {i+1}: n={n}, m={m}, p={p}")
        
        # Reset
        await reset_dut(dut)
        
        # Write inputs
        dut.n.value = n
        dut.m.value = m
        dut.p.value = p
        await write_array(dut, 'a', a_list, ARRAY_SIZE_A, DATA_WIDTH)
        await write_array(dut, 'b', b_list, ARRAY_SIZE_B, DATA_WIDTH)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        await wait_for_done(dut)
        
        # Read results
        count = int(dut.count.value)
        positions = await read_positions(dut, count)
        
        # Verify
        dut._log.info(f"  Found {count} positions: {positions}")
        
        # Check count
        if count != len(expected):
            raise TestFailure(f"Test {i+1}: Expected {len(expected)} positions, got {count}")
        
        # Check positions match (order-independent check)
        sorted_positions = sorted(positions)
        sorted_expected = sorted(expected)
        if sorted_positions != sorted_expected:
            raise TestFailure(f"Test {i+1}: Positions mismatch. Expected {sorted_expected}, got {sorted_positions}")
        
        dut._log.info(f"  Test {i+1} PASSED")
    
    dut._log.info("All tests passed!")
