import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# CONFIGURATION
DATA_WIDTH = 8
MAX_N = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# HELPER FUNCTIONS
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

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# Function to compute expected result
def compute_expected(species_list):
    n = len(species_list)
    if n == 0:
        return 0
    dp = [1] * n
    for i in range(1, n):
        for j in range(i):
            if species_list[j] <= species_list[i]:
                if dp[j] + 1 > dp[i]:
                    dp[i] = dp[j] + 1
    lnds = max(dp)
    return n - lnds

# Main test
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_min_replant(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: each is (n, species_list, description)
    test_cases = [
        (3, [2,1,1], "Example 1"),
        (3, [1,2,3], "Example 2"),
        (6, [1,2,1,3,1,1], "Example 3"),
        (1, [1], "Single plant"),
        (8, [1,1,1,2,1,2,2,2], "Example 5 (first 8)"),
        (15, [4,2,2,2,4,5,5,5,5,5,4,2,1,3,2], "Example 6"),
        (10, [4,1,3,7,2,6,6,7,1,5], "Example 7"),
        (5, [5,4,3,2,1], "Example 8"),
        (12, [2,2,3,3,3,1,5,3,3,3,4,4], "Example 9"),
        (3, [2,1,3], "Example 10"),
        (3, [3,1,2], "Example 11"),
        (4, [1,2,1,2], "Example 12"),
        (16, [1,2,3,4,5,6,7,8,9,10,1,2,3,4,5,6], "Example 13 (first 16)"),
        (12, [3,3,3,3,3,1,1,2,4,4,2,3], "Example 14"),
        (16, [1,1,2,2,2,2,1,1,2,2,1,1,2,2,2,2], "Example 15"),
        (10, [1,2,3,5,9,8,6,7,4,10], "Example 16"),
        (10, [5,3,1,6,1,2,1,6,5,4], "Example 17"),
        (16, [1,1,2,1,2,1,2,2,1,1,2,2,1,2,1,2], "Example 18 (first 16)"),
        (16, [6,10,15,9,3,2,9,8,1,5,14,7,13,4,1,7], "Example 19 (first 16)"),
        (15, [1,2,3,1,2,3,1,2,3,1,2,3,1,2,3], "Example 20"),
        (10, [2,2,2,2,2,1,1,1,1,1], "Example 21"),
        (11, [2,2,2,2,2,3,1,1,1,1,1], "Example 22"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, species_list, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        # Compute expected result
        expected = compute_expected(species_list)
        cocotb.log.info(f"  Expected: {expected}")
        
        # Set n and species
        dut.n.value = n
        # Initialize all species to 0
        for j in range(MAX_N):
            dut.species[j].value = 0
        # Set the actual species
        for j, s in enumerate(species_list):
            dut.species[j].value = s
        
        # Start computation
        await start_computation(dut)
        
        # Wait for done
        try:
            await wait_for_done(dut)
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
            continue
        
        # Read result
        if not is_value_defined(dut.result.value):
            cocotb.log.error("  FAIL: Result is undefined (X/Z)")
            failed += 1
            continue
        
        result = int(dut.result.value)
        
        if result != expected:
            cocotb.log.error(f"  FAIL: Expected {expected}, got {result}")
            failed += 1
        else:
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")