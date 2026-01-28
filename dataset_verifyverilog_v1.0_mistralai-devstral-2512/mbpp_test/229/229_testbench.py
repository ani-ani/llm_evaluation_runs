import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_array(dut, name, vals, width=8):
    """Write individual array elements"""
    for i, v in enumerate(vals):
        # Convert negative numbers to unsigned for HDL assignment
        unsigned_val = from_signed(v, width)
        getattr(dut, name)[i].value = clamp_to_width(unsigned_val, width)

async def read_array(dut, name, width=8):
    """Read individual array elements"""
    result = []
    for i in range(8):
        val = getattr(dut, name)[i].value
        if is_value_defined(val):
            unsigned_val = int(val)
            signed_val = to_signed(unsigned_val, width)
            result.append(signed_val)
        else:
            result.append(0)
    return result

@cocotb.test(timeout_time=1000, timeout_unit='ms')
async def test_rearrange_array(dut):
    # Clock setup
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        ([1, 2, -3, 4, 5, 6, -7, 8], 8, [-1, -3, -7, 4, 5, 6, 2, 8]),
        ([-1, 2, -3, 4, 5, 6, -7, 8], 8, [-1, -3, -7, 4, 5, 6, 2, 8]),
        ([12, -14, -26, 13, 15, 0, 0, 0], 5, [-14, -26, 12, 13, 15, 0, 0, 0]),
        ([10, 24, 36, -42, -39, -78, 85, 0], 7, [-42, -39, -78, 10, 24, 36, 85, 0]),
        ([5, -2, 10, -3, 7, -1, 8, 4], 8, [-2, -3, -1, 5, 10, 7, 8, 4])
    ]
    
    passed = failed = 0
    
    for idx, (arr, n, expected) in enumerate(test_cases, 1):
        cocotb.log.info(f"Test {idx}: Input={arr[:n]}, n={n}")
        try:
            # Write input array
            await write_array(dut, 'arr', arr, 8)
            
            # Set len and start
            dut.len.value = n
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read result array
            result = await read_array(dut, 'result', 8)
            
            # Compare with expected (only first n elements matter)
            result_n = result[:n]
            if result_n != expected:
                raise TestFailure(f"Expected {expected}, got {result_n}")
            
            cocotb.log.info(f"  PASS: Result={result_n}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} of {passed+failed} tests failed")