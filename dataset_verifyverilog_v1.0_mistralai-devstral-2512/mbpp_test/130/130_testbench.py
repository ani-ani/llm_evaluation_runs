import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 16
CLK_NS = 20
MAX_CYCLES = 150

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except (ValueError, TypeError):
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except (ValueError, TypeError):
        return default

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def write_array(dut, name, vals, width):
    for i, v in enumerate(vals):
        if i < ARRAY_SIZE:
            dut.__getattr__(name)[i].value = clamp_to_width(v, width)

async def compute_expected(nums):
    """Compute expected result using Python logic"""
    if not nums:
        return 0
    freq = {}
    for n in nums:
        freq[n] = freq.get(n, 0) + 1
    # Find max frequency, with tiebreaker to smaller value (first in iteration)
    max_val = None
    max_count = 0
    for val, count in sorted(freq.items()):  # Sort for deterministic tiebreaker
        if count > max_count:
            max_count = count
            max_val = val
    return max_val if max_val is not None else 0

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_max_occurrences(dut):
    # Setup
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational - just set inputs
        await Timer(10, units='ns')
    
    # Test cases from Python specification
    test_cases = [
        ([2,3,8,4,7,9,8,2,6,5,1,6,1,2,3,2], 2, "Test 1: Multiple values, 2 appears 4 times"),
        ([2,3,8,4,7,9,8,7,9,15,14,10,12,13,16,18], 8, "Test 2: 8 and 9 appear twice, return 8"),
        ([10,20,20,30,40,90,80,50,30,20,50,10], 20, "Test 3: 20 appears 3 times"),
        ([5,5,5,5], 5, "Test 4: Single value repeated"),
        ([1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16], 1, "Test 5: All unique (return smallest)"),
        ([], 0, "Test 6: Empty array"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (inp, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Write inputs
            await write_array(dut, 'arr', inp, DATA_WIDTH)
            dut.len.value = len(inp)
            
            if is_seq:
                # Start operation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
                result = safe_int(dut.result.value)
            else:
                # Combinational - wait for propagation
                await Timer(50, units='ns')
                result = safe_int(dut.result.value)
            
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            
            # Verify done signal for sequential
            if is_seq and has_signal(dut, 'done'):
                if int(dut.done.value) != 1:
                    raise TestFailure("done signal not high after completion")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL - {desc}: {e}")
            failed += 1
    
    # Additional edge cases
    cocotb.log.info("Testing edge cases...")
    
    # Test with len > actual array (should only process len elements)
    try:
        # [2,2,3,3] with len=2 -> only 2,2 -> max=2
        await write_array(dut, 'arr', [2,2,3,3], DATA_WIDTH)
        dut.len.value = 2
        if is_seq:
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut)
            result = safe_int(dut.result.value)
        else:
            await Timer(50, units='ns')
            result = safe_int(dut.result.value)
        
        if result != 2:
            raise TestFailure(f"Partial array test failed: Expected 2, got {result}")
        passed += 1
    except TestFailure as e:
        cocotb.log.error(f"FAIL - Partial array: {e}")
        failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    else:
        cocotb.log.info(f"All {passed} tests passed!")
