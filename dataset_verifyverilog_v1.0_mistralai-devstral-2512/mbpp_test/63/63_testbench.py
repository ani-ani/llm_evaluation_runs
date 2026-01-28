import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
PAIRS_WIDTH = 128  # 8 pairs * 16 bits per pair
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 100

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

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

def pack_pairs(pairs, elem_width=8):
    """Pack list of pairs into 128-bit value."""
    result = 0
    for i, (a, b) in enumerate(pairs):
        # Pack a into bits [i*16+7:i*16], b into bits [i*16+15:i*16+8]
        a_val = a & ((1 << elem_width) - 1)
        b_val = b & ((1 << elem_width) - 1)
        result |= (a_val << (i * 16))
        result |= (b_val << (i * 16 + 8))
    return result

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_max_difference(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (input_pairs, expected_max_diff, description)
    test_cases = [
        ([(3, 5), (1, 7), (10, 3), (1, 2)], 7, "Simple test 1"),
        ([(4, 6), (2, 17), (9, 13), (11, 12)], 15, "Simple test 2"),
        ([(12, 35), (21, 27), (13, 23), (41, 22)], 23, "Simple test 3"),
        ([(0, 255), (127, -128)], 255, "Max range test"),
        ([], 0, "Empty array test"),
        ([(5, 5)], 0, "Equal values test"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (pairs, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Pack pairs into input port
            packed = pack_pairs(pairs)
            dut.pairs_in.value = packed
            dut.valid_pairs.value = len(pairs)
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Check result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: result={result}")
            
            # Wait for done to go low
            await RisingEdge(dut.clk)
            if int(dut.done.value) != 0:
                cocotb.log.warning("Done signal did not deassert in 1 cycle")
                
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
    
    cocotb.log.info(f"All {passed} tests passed!")