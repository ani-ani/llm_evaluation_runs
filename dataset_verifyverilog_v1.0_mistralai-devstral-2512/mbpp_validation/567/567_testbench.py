import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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
MAX_CYCLES = 50

async def write_array(dut, name, vals, width):
    for i, v in enumerate(vals):
        if has_signal(dut, f'{name}_{i}'):
            getattr(dut, f'{name}_{i}').value = clamp_to_width(v, width)
        elif has_signal(dut, name):
            dut.__getattr__(name)[i].value = clamp_to_width(v, width)
        else:
            raise TestFailure(f"Array signal {name} not found")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_sorted_array(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        ([1,2,4,6,8,10,12,14,16,17], 1, "sorted increasing"),
        ([1, 2, 4, 6, 8, 10, 12, 14, 20, 17], 0, "unsorted - drop"),
        ([1, 2, 4, 6, 8, 10,15,14,20], 0, "unsorted - middle drop"),
        ([5,5,5,5], 1, "all equal"),
        ([1], 1, "single element"),
        ([], 1, "empty (len=0)"),
        ([10,9,8,7], 0, "decreasing"),
    ]
    
    passed = failed = 0
    
    for i, (vals, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Set array values
            await write_array(dut, 'arr', vals, DATA_WIDTH)
            
            # Set length
            if has_signal(dut, 'len'):
                dut.len.value = clamp_to_width(len(vals), 4)
            
            # Start comparison
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            # Check result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: {desc}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed")
