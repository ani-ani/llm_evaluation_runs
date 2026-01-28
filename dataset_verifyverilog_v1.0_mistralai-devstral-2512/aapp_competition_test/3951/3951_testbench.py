import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

# GCD calculation (Python)
def gcd(a, b):
    while b:
        a, b = b, a % b
    return a

# Generate test case
def generate_test_case(n):
    # Generate n random numbers (scaled to 16-bit for FPGA testing)
    values = [random.randint(1, 65535) for _ in range(n)]
    values.sort(reverse=True)
    
    # Generate GCD table
    gcd_table = []
    for i in range(n):
        for j in range(n):
            gcd_table.append(gcd(values[i], values[j]))
    
    # Shuffle for input simulation
    random.shuffle(gcd_table)
    
    return values, gcd_table

# Wait for done signal
async def wait_for_done(dut, max_cycles=6000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Reset DUT
async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'num_valid'): dut.num_valid.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Main test
@cocotb.test(timeout_time=10, timeout_unit='ms')
async def test_gcd_table_solver(dut):
    """
    Test the GCD table solver with various test cases
    """
    
    # Parameters
    CLK_NS = 10
    MAX_VALUES = 16
    MAX_TABLE_SIZE = 256
    
    # Check required signals
    required_signals = ['clk', 'rst_n', 'start', 'num_valid', 'num_in', 
                        'result_valid', 'busy', 'done']
    for sig in required_signals:
        if not has_signal(dut, sig):
            cocotb.log.error(f"Missing required signal: {sig}")
            raise TestFailure(f"Missing signal {sig}")
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Test cases
    test_cases = [
        # (n, description)
        (1, "Single element"),
        (2, "Two elements"),
        (4, "Four elements (sample case)"),
        (8, "Eight elements"),
        (16, "Maximum elements"),
    ]
    
    for test_num, (n, desc) in enumerate(test_cases):
        cocotb.log.info(f"\n=== Test {test_num + 1}: {desc} (n={n}) ===")
        
        # Generate test data
        expected_array, gcd_table = generate_test_case(n)
        table_len = len(gcd_table)
        
        cocotb.log.info(f"Expected array: {expected_array}")
        cocotb.log.info(f"GCD table length: {table_len}")
        
        # Reset
        await reset_dut(dut)
        
        # Check initial state
        if int(dut.busy.value) != 0:
            raise TestFailure("DUT not idle after reset")
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for accumulation phase
        await RisingEdge(dut.clk)
        
        # Feed GCD table entries
        cocotb.log.info("Feeding GCD table entries...")
        for idx, val in enumerate(gcd_table):
            dut.num_valid.value = 1
            dut.num_in.value = clamp_to_width(val, 32)
            await RisingEdge(dut.clk)
            dut.num_valid.value = 0
            
            # Check busy flag
            if not int(dut.busy.value):
                cocotb.log.error(f"Busy flag dropped unexpectedly at entry {idx}")
        
        # Wait for result
        cocotb.log.info("Waiting for result...")
        await wait_for_done(dut)
        
        # Read result
        if not int(dut.result_valid.value):
            raise TestFailure("Result valid flag not set")
        
        result_len = int(dut.result_len.value)
        if result_len != n:
            raise TestFailure(f"Result length mismatch: expected {n}, got {result_len}")
        
        # Read result array
        result_array = []
        if has_signal(dut, 'result_array'):
            for i in range(n):
                # Individual access for array elements
                elem_val = getattr(dut, f'result_array_{i}').value
                if is_value_defined(elem_val):
                    result_array.append(int(elem_val))
                else:
                    raise TestFailure(f"Result array element {i} undefined")
        else:
            # Fallback: assume packed or other structure
            raise TestFailure("Result array structure not supported")
        
        # Sort for comparison (since order may differ)
        result_array.sort(reverse=True)
        
        # Compare
        if result_array != expected_array:
            cocotb.log.error(f"Mismatch!")
            cocotb.log.error(f"Expected: {expected_array}")
            cocotb.log.error(f"Got:      {result_array}")
            raise TestFailure(f"Test {desc} failed")
        
        cocotb.log.info(f"Test {desc} passed!")
        
        # Small delay between tests
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    cocotb.log.info("\nAll tests passed!")

# Edge case tests
@cocotb.test(timeout_time=5, timeout_unit='ms')
async def test_edge_cases(dut):
    """
    Test edge cases and error conditions
    """
    
    CLK_NS = 10
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Test: Maximum table size (16x16 = 256)
    cocotb.log.info("Testing maximum table size (256 entries)...")
    
    await reset_dut(dut)
    
    # Generate max table (all 1s for simplicity)
    max_table = [1] * 256
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Feed all entries
    for val in max_table:
        dut.num_valid.value = 1
        dut.num_in.value = val
        await RisingEdge(dut.clk)
        dut.num_valid.value = 0
    
    # Wait for completion
    await wait_for_done(dut)
    
    # Verify result (should be [1] repeated)
    result_len = int(dut.result_len.value)
    if result_len != 1:
        raise TestFailure(f"Expected 1 element, got {result_len}")
    
    # Check first element (if accessible)
    if has_signal(dut, 'result_array_0'):
        first_elem = int(dut.result_array_0.value)
        if first_elem != 1:
            raise TestFailure(f"Expected element 1, got {first_elem}")
    
    cocotb.log.info("Maximum table test passed!")
    
    # Test: Single element (42)
    cocotb.log.info("Testing single element (42)...")
    
    await reset_dut(dut)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Feed single entry: [42]
    dut.num_valid.value = 1
    dut.num_in.value = 42
    await RisingEdge(dut.clk)
    dut.num_valid.value = 0
    
    await wait_for_done(dut)
    
    result_len = int(dut.result_len.value)
    if result_len != 1:
        raise TestFailure(f"Expected 1 element, got {result_len}")
    
    if has_signal(dut, 'result_array_0'):
        first_elem = int(dut.result_array_0.value)
        if first_elem != 42:
            raise TestFailure(f"Expected 42, got {first_elem}")
    
    cocotb.log.info("Single element test passed!")

# Performance test
@cocotb.test(timeout_time=15, timeout_unit='ms')
async def test_performance(dut):
    """
    Test with maximum realistic case: n=16, varied GCDs
    """
    
    CLK_NS = 10
    MAX_CYCLES = 5000
    
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Generate realistic test case
    n = 16
    values = []
    for i in range(n):
        # Mix of powers of 2 and odd numbers for varied GCDs
        if i % 4 == 0:
            values.append(2**(i//4 + 1))
        else:
            values.append(random.randint(100, 1000))
    values.sort(reverse=True)
    
    # Build GCD table
    gcd_table = []
    for i in range(n):
        for j in range(n):
            gcd_table.append(gcd(values[i], values[j]))
    random.shuffle(gcd_table)
    
    cocotb.log.info(f"Testing with n={n}, table size={len(gcd_table)}")
    
    await reset_dut(dut)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Feed table
    cycle_count = 0
    for val in gcd_table:
        dut.num_valid.value = 1
        dut.num_in.value = clamp_to_width(val, 32)
        await RisingEdge(dut.clk)
        dut.num_valid.value = 0
        cycle_count += 1
        
        if cycle_count > MAX_CYCLES:
            raise TestFailure(f"Exceeded cycle limit: {MAX_CYCLES}")
    
    # Wait for result
    await wait_for_done(dut, max_cycles=MAX_CYCLES - cycle_count)
    
    # Verify
    result_len = int(dut.result_len.value)
    if result_len != n:
        raise TestFailure(f"Length mismatch: expected {n}, got {result_len}")
    
    # Read and verify elements
    result_values = []
    for i in range(n):
        elem_val = getattr(dut, f'result_array_{i}').value
        result_values.append(int(elem_val))
    
    result_values.sort(reverse=True)
    
    if result_values != values:
        cocotb.log.error(f"Expected: {values}")
        cocotb.log.error(f"Got: {result_values}")
        raise TestFailure("Performance test failed")
    
    cocotb.log.info(f"Performance test passed in {cycle_count} cycles")
