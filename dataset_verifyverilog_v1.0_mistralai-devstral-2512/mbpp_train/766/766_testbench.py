import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Global constants for this testbench
DATA_WIDTH = 8
RESULT_WIDTH = 16
LEN_WIDTH = 4
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 100

# MANDATORY HELPERS
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# ARRAY ACCESS HELPER
def write_array(dut, name, vals, width):
    """Write values to an array element by element"""
    for i, v in enumerate(vals):
        dut.__getattr__(name)[i].value = clamp_to_width(v, width)

# RESULT DECODING
def decode_pair(packed_val):
    """Extract (high_byte, low_byte) from 16-bit result"""
    low_byte = packed_val & 0xFF
    high_byte = (packed_val >> 8) & 0xFF
    return (high_byte, low_byte)

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

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_pair_wise(dut):
    """Test consecutive pair generation from arrays"""
    
    # Setup clock if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational module
        await Timer(100, units='ns')
    
    # Test cases: (input_array, expected_pairs)
    test_cases = [
        ([1, 1, 2, 3, 3, 4, 4, 5], [(1, 1), (2, 1), (3, 2), (3, 3), (4, 3), (4, 4), (5, 4)], "case_8_elements"),
        ([1, 5, 7, 9, 10], [(5, 1), (7, 5), (9, 7), (10, 9)], "case_5_elements"),
        ([5, 1, 9, 7, 10], [(1, 5), (9, 1), (7, 9), (10, 7)], "case_5_reversed"),
        ([1, 2, 3, 4, 5, 6, 7, 8, 9, 10], [(2, 1), (3, 2), (4, 3), (5, 4), (6, 5), (7, 6), (8, 7), (9, 8), (10, 9)], "case_10_elements"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (inp, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} (len={len(inp)})")
        
        try:
            # Write input array
            for idx, val in enumerate(inp):
                if idx < ARRAY_SIZE:
                    getattr(dut, f'arr_{idx}').value = clamp_to_width(val, DATA_WIDTH)
            
            # Set length
            dut.len.value = len(inp) & ((1 << LEN_WIDTH) - 1)
            
            # Expected outputs
            expected_pairs = expected
            num_pairs = len(expected_pairs)
            
            if num_pairs > 0:
                # Sequential execution
                if is_seq:
                    dut.start.value = 1
                    await RisingEdge(dut.clk)
                    dut.start.value = 0
                    
                    # Collect all pairs
                    collected = []
                    for pair_idx in range(num_pairs):
                        await wait_for_done(dut)
                        result_val = int(dut.result.value)
                        pair = decode_pair(result_val)
                        collected.append(pair)
                        cocotb.log.info(f"  Pair {pair_idx}: {pair}")
                        
                        # Wait for done to go low
                        await RisingEdge(dut.clk)
                    
                    # Verify
                    if len(collected) != num_pairs:
                        raise TestFailure(f"Expected {num_pairs} pairs, got {len(collected)}")
                    
                    for idx, (exp, got) in enumerate(zip(expected_pairs, collected)):
                        if exp != got:
                            raise TestFailure(f"Pair {idx}: expected {exp}, got {got}")
                else:
                    # Combinational: verify done and result immediately
                    await Timer(10, units='ns')
                    if not is_value_defined(dut.done.value) or int(dut.done.value) != 1:
                        raise TestFailure("done signal not asserted for non-empty array")
                    result_val = int(dut.result.value)
                    pair = decode_pair(result_val)
                    if pair != expected_pairs[0]:
                        raise TestFailure(f"Expected {expected_pairs[0]}, got {pair}")
                    
                    # For combinational, only test first pair
                    # Additional pairs would require multiple done pulses which combinational can't do
            else:
                # Empty array case (no pairs expected)
                if is_seq:
                    dut.start.value = 1
                    await RisingEdge(dut.clk)
                    dut.start.value = 0
                    
                    # Should not get done pulse
                    for _ in range(20):
                        await RisingEdge(dut.clk)
                        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                            raise TestFailure("Got unexpected done pulse for empty/no-pair case")
                    
                    # Check result is 0
                    if is_value_defined(dut.result.value) and int(dut.result.value) != 0:
                        raise TestFailure(f"Expected result=0, got {int(dut.result.value)}")
                else:
                    # Combinational with no pairs
                    await Timer(10, units='ns')
                    # done should be 0
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        raise TestFailure("done=1 for empty/no-pair case")
            
            passed += 1
            cocotb.log.info(f"  PASS")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL [{desc}]: {e}")
            failed += 1
        
        # Reset for next test
        if is_seq:
            dut.start.value = 0
            dut.rst_n.value = 0
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
            dut.rst_n.value = 1
            await RisingEdge(dut.clk)
    
    # Edge case: len=0 (no elements, no pairs)
    cocotb.log.info("Testing edge case: len=0")
    try:
        dut.len.value = 0
        # Clear all array values
        for idx in range(ARRAY_SIZE):
            getattr(dut, f'arr_{idx}').value = 0
        
        if is_seq:
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            for _ in range(20):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    raise TestFailure("Got unexpected done pulse for len=0")
            
            if is_value_defined(dut.result.value) and int(dut.result.value) != 0:
                raise TestFailure(f"Expected result=0 for len=0, got {int(dut.result.value)}")
        else:
            await Timer(10, units='ns')
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                raise TestFailure("done=1 for len=0")
        
        passed += 1
        cocotb.log.info("  PASS")
    except TestFailure as e:
        cocotb.log.error(f"FAIL [len=0]: {e}")
        failed += 1
    
    # Edge case: len=1 (single element, no pairs)
    cocotb.log.info("Testing edge case: len=1")
    try:
        getattr(dut, 'arr_0').value = 42
        dut.len.value = 1
        
        if is_seq:
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            for _ in range(20):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    raise TestFailure("Got unexpected done pulse for len=1")
            
            if is_value_defined(dut.result.value) and int(dut.result.value) != 0:
                raise TestFailure(f"Expected result=0 for len=1, got {int(dut.result.value)}")
        else:
            await Timer(10, units='ns')
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                raise TestFailure("done=1 for len=1")
        
        passed += 1
        cocotb.log.info("  PASS")
    except TestFailure as e:
        cocotb.log.error(f"FAIL [len=1]: {e}")
        failed += 1
    
    # Summary
    cocotb.log.info(f"\nSUMMARY: {passed} passed, {failed} failed")
    if failed:
        raise TestFailure(f"{failed} test(s) failed")