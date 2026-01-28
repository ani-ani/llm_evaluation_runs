import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math
from itertools import product

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8      # Each input value is 8 bits
ARRAY_SIZE = 20     # 20 entries: 5 monsters * 4 foods, but provided in two lines
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    """Convert unsigned integer to signed (two's complement)."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    """Convert signed integer to unsigned for Verilog assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_proportions_solver(dut):
    """Test the proportions solver module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (input_string, expected_output)
    test_cases = [
        ("_ 90 22 _ 6 _ _ _ _ 81\n_ 40 _ _ _ 12 60 _ 90 _", 1),
        ("85 55 _ 99 51 _ _ _ _ _\n_ _ _ _ _ _ _ 85 63 153", 1),
        ("160 _ _ 136 _ _ _ _ _ 170\n_ _ _ _ 120 _ _ 144 _ _", 8640),
        ("36 99 _ 55 _ 99 _ 77 _ _\n_ 144 _ _ 27 _ 21 112 _ _", -1),  # -1 represents "many"
    ]
    
    for i, (input_str, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test case {i+1}: {input_str[:50]}...")
        
        # Parse input string into 20 values
        lines = input_str.strip().split('\n')
        first_line = lines[0].split()
        second_line = lines[1].split()
        
        # Combine into 20-element list
        values = []
        for token in first_line:
            if token == '_':
                values.append(0)  # Will be handled as unknown in testbench
            else:
                values.append(int(token))
        for token in second_line:
            if token == '_':
                values.append(0)
            else:
                values.append(int(token))
        
        # Write inputs to DUT
        for idx in range(20):
            if idx < 10:
                port_name = f'arr_{idx}'
            else:
                port_name = f'arr_{idx}'  # Since we have 20 ports from arr_0 to arr_19
            
            if has_signal(dut, port_name):
                # For underscores, we write 0 but will mark them as unknown in testbench logic
                # In real test, we would need to handle unknowns, but for simplicity we write the known values
                # The DUT should interpret 0 as placeholder for unknown? But note: known values are positive integers.
                # So we can use 0 to represent underscore? But the problem says positive integers, so 0 is invalid.
                # However, in the testbench, we will only provide known values and the DUT must handle underscores.
                # Since the DUT interface expects all 20 values, we must provide them.
                # We'll use 0 to represent underscore, and the DUT must interpret 0 as "unknown".
                # But note: the problem says known values are positive, so 0 is safe as marker.
                # However, the DUT must be designed to handle 0 as missing data.
                # For the sake of this test, we assume the DUT ignores zeros and only uses positive values.
                # But wait: the problem says the known entries are positive, so we can use 0 as marker for underscore.
                # So we write the value as is.
                getattr(dut, port_name).value = clamp_to_width(values[idx], DATA_WIDTH)
            else:
                raise TestFailure(f"Signal {port_name} not found")
        
        # Start computation
        await start_computation(dut)
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i+1}: Result is undefined")
        
        result = int(dut.result.value)
        
        if expected == -1:
            # Expect "many" -> represented by a special value? But the problem says output "many" as string.
            # In our test, we expect the DUT to output a large number? But the problem says output "many".
            # Since the Verilog output is a number, we cannot output a string. We need to define a convention.
            # Let's use a special value like 0 to represent "many"? But 0 might be a valid count.
            # Alternatively, we can output -1? But the result is 32-bit unsigned? We defined result as 32-bit reg.
            # We'll use 0xFFFFFFFF to represent "many"? But note: the example output for "many" is string.
            # We need to change the problem output to be a number, and if the number is too large to represent, we output a special value.
            # But the problem says output "many" as string. So we cannot use a numeric output for "many".
            # Therefore, we must change the problem specification for HDL: output a 32-bit result, and if the result is 0xFFFFFFFF, it means "many".
            # Alternatively, we can have an additional output signal that indicates "many".
            # But the problem only has one output: result.
            # We'll assume that the DUT outputs a number, and if the number of solutions is too large (greater than 2^32-1), we output 0xFFFFFFFF.
            # But the problem says "infinitely many", so we output "many". In our test, we expect the DUT to output 0xFFFFFFFF.
            # So we define: if expected is -1, then we expect result == 0xFFFFFFFF.
            if result != 0xFFFFFFFF:
                raise TestFailure(f"Test {i+1}: Expected many (0xFFFFFFFF), got {result}")
        else:
            if result != expected:
                raise TestFailure(f"Test {i+1}: Expected {expected}, got {result}")
        
        cocotb.log.info(f"Test {i+1}: PASS")
    
    cocotb.log.info("All tests passed!")
