import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
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

DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 200

async def wait_for_done(dut, max_cycles=200):
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

async def set_array_elements(dut, prefix, values, width):
    """Set individual array elements like arr_0, arr_1, etc."""
    for i, v in enumerate(values):
        attr_name = f"{prefix}_{i}"
        if has_signal(dut, attr_name):
            getattr(dut, attr_name).value = clamp_to_width(v, width)
        else:
            # Try a[0] syntax
            attr_name = f"{prefix}"
            if has_signal(dut, attr_name):
                dut.__getattr__(attr_name)[i].value = clamp_to_width(v, width)

async def pack_array(vals, bits=8):
    """Pack array into single value for packed input"""
    r = 0
    for i, v in enumerate(vals):
        r |= (v & ((1 << bits) - 1)) << (i * bits)
    return r

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_is_sub_array(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases from the Python function
    # Test 1: A=[1,4,3,5], B=[1,2] -> False
    # Test 2: A=[1,2,1], B=[1,2,1] -> True
    # Test 3: A=[1,0,2,2], B=[2,2,0] -> False
    
    test_cases = [
        ("Test 1: [1,4,3,5] vs [1,2] -> False",
         [1,4,3,5], 4, [1,2], 2, False),
        ("Test 2: [1,2,1] vs [1,2,1] -> True",
         [1,2,1], 3, [1,2,1], 3, True),
        ("Test 3: [1,0,2,2] vs [2,2,0] -> False",
         [1,0,2,2], 4, [2,2,0], 3, False),
    ]
    
    passed = 0
    failed = 0
    
    for idx, (desc, a_vals, n, b_vals, m, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {idx+1}: {desc}")
        try:
            # Fill array A elements
            await set_array_elements(dut, 'a', a_vals + [0]*(ARRAY_SIZE - n), DATA_WIDTH)
            # Fill array B elements
            await set_array_elements(dut, 'b', b_vals + [0]*(ARRAY_SIZE - m), DATA_WIDTH)
            
            # Set lengths
            if has_signal(dut, 'n'):
                dut.n.value = n
            if has_signal(dut, 'm'):
                dut.m.value = m
            
            if is_seq:
                # Start search
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for completion
                await wait_for_done(dut)
                
                # Read result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result signal undefined after done")
                
                result = int(dut.result.value)
            else:
                # Combinational - small delay
                await Timer(100, units='ns')
                result = int(dut.result.value) if is_value_defined(dut.result.value) else 0
            
            if result != int(expected):
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: result={result}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
            if is_seq:
                await reset_dut(dut)
        
        # Reset between tests
        if is_seq and idx < len(test_cases) - 1:
            await reset_dut(dut)
    
    cocotb.log.info(f"\nTotal: {passed} passed, {failed} failed")
    if failed:
        raise TestFailure(f"{failed} tests failed")