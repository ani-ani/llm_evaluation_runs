import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH, PAIR_COUNT, CLK_NS, MAX_CYCLES = 8, 8, 10, 100

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

async def write_pairs(dut, pairs):
    """Write pairs to dut.pairs[i][j] for i in 0-7, j in 0-1"""
    for i in range(min(len(pairs), PAIR_COUNT)):
        for j in range(2):
            signed_val = pairs[i][j]
            # Convert to 8-bit two's complement
            if signed_val < 0:
                packed = signed_val & 0xFF
            else:
                packed = signed_val
            dut.pairs[i][j].value = packed

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_max_pair_product(dut):
    """Test maximum absolute product of pairs"""
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (input_pairs, expected_result, description)
    test_cases = [
        ([(2,7), (2,6), (1,8), (4,9), (5,5), (3,3), (1,1), (0,0)], 36, "Test 1: positive ints"),
        ([(10,20), (15,2), (5,10), (7,8), (9,3), (4,12), (6,15), (1,50)], 200, "Test 2: mixed magnitudes"),
        ([(11,44), (10,15), (20,5), (12,9), (3,30), (8,20), (15,12), (2,100)], 484, "Test 3: large products"),
        ([(0,0), (0,0), (0,0), (0,0), (0,0), (0,0), (0,0), (0,0)], 0, "Test 4: all zeros"),
        ([(127,127), (-128,-128), (0,0), (0,0), (0,0), (0,0), (0,0), (0,0)], 16129, "Test 5: edge values"),
        ([(100,100), (50,50), (20,20), (10,10), (5,5), (1,1), (0,0), (-5,-5)], 10000, "Test 6: square numbers"),
        ([(1,-1), (2,-2), (3,-3), (4,-4), (5,-5), (6,-6), (7,-7), (8,-8)], 64, "Test 7: negative products"),
        ([(15,20), (16,19), (17,18), (18,17), (19,16), (20,15), (21,14), (22,13)], 330, "Test 8: adjacent pairs"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (pairs, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {desc}")
        cocotb.log.info(f"Input: {pairs}")
        cocotb.log.info(f"Expected: {expected}")
        
        try:
            # Write pairs to DUT
            await write_pairs(dut, pairs)
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut, max_cycles=MAX_CYCLES)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            cocotb.log.info(f"Result: {result}")
            
            # Validate
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed}/{len(test_cases)} tests failed")
    
    cocotb.log.info(f"\n=== SUMMARY: {passed}/{len(test_cases)} tests passed ===")
