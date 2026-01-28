import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH, ARRAY_SIZE, CLK_NS, MAX_CYCLES = 32, 8, 10, 1000

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

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

def write_array(dut, name, vals, width):
    for i, v in enumerate(vals):
        dut.__getattr__(name)[i].value = clamp_to_width(v, width)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_or_max(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (arr, k, x, expected_result)
    test_cases = [
        ([1, 1, 1, 0, 0, 0, 0, 0], 1, 2, 3),
        ([1, 2, 4, 8, 0, 0, 0, 0], 2, 3, 79),
        ([12, 9, 0, 0, 0, 0, 0, 0], 1, 2, 30),
        ([12, 7, 0, 0, 0, 0, 0, 0], 1, 2, 31),
        ([3, 2, 0, 0, 0, 0, 0, 0], 1, 3, 11),
        ([1, 0, 0, 0, 0, 0, 0, 0], 1, 2, 2),
        ([0, 0, 0, 0, 0, 0, 0, 0], 1, 2, 0),
    ]
    
    passed = failed = 0
    
    for i, (arr, k, x, exp) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: arr={arr[:8]}, k={k}, x={x}")
        try:
            # Write inputs
            write_array(dut, 'arr', arr, DATA_WIDTH)
            dut.k.value = k
            dut.x.value = x
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
                result = safe_int(dut.result.value)
            else:
                await Timer(100, units='ns')
                result = safe_int(dut.result.value)
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}"); failed += 1
    
    if failed: raise TestFailure(f"{failed} tests failed")