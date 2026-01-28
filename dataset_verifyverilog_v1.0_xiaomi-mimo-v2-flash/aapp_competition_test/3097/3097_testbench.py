import cocotb
from cocotb.triggers import Timer, RisingEdge, ClockCycles
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=2000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Python implementation of the board logic for verification
def reverse_digits(n):
    s = str(n)
    return int(s[::-1])

def count_in_board_py(min_val, max_val, max_row=64, max_val_limit=10**10):
    total = 0
    for r in range(1, max_row + 1):
        curr = r
        while curr <= max_val_limit:
            if min_val <= curr <= max_val:
                total += 1
            if curr > max_val:
                break
            next_val = curr + reverse_digits(curr)
            if next_val > max_val_limit:
                break
            curr = next_val
    return total

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_board_count(dut):
    # Setup clock
    clk = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clk.start())
    
    await reset_dut(dut)
    
    # Test cases: (min_val, max_val, expected_count)
    # Note: Scaled values might differ slightly if implementation limits rows/cols
    # Based on problem examples and constraints
    test_cases = [
        (1, 10, 18),      # Sample 1
        (5, 8, 8),        # Sample 1
        (17, 144, 265),   # Sample 2
        (121, 121, 25),   # Sample 2
        (89, 98, 10),     # Sample 2
    ]
    
    for i, (a, b, expected) in enumerate(test_cases):
        cocotb.log.info(f"Running test {i+1}: A={a}, B={b}")
        
        # Drive inputs
        dut.min_val.value = a
        dut.max_val.value = b
        dut.start.value = 1
        
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.count.value):
            raise TestFailure("Result count is undefined")
            
        result = int(dut.count.value)
        
        # Verify
        if result != expected:
            raise TestFailure(f"Test {i+1} failed: Expected {expected}, got {result}")
        
        cocotb.log.info(f"Test {i+1} passed: {result}")
        
        await RisingEdge(dut.clk)
