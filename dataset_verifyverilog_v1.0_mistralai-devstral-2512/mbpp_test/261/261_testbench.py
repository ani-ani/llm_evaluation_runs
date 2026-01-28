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
ARRAY_SIZE = 4
CLK_NS = 10
MAX_CYCLES = 200

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_arrays(dut, tuple1, tuple2):
    for i in range(ARRAY_SIZE):
        dut.tuple1[i].value = clamp_to_width(tuple1[i], DATA_WIDTH)
        dut.tuple2[i].value = clamp_to_width(tuple2[i], DATA_WIDTH)

def pack_result(quotients):
    packed = 0
    for i in range(ARRAY_SIZE):
        packed |= (quotients[i] & 0xF) << (i * 4)
    return packed

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_division_elements(dut):
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        raise TestFailure("Module must be sequential with 'clk' signal")
    
    test_cases = [
        ((10, 4, 6, 9), (5, 2, 3, 3), (2, 2, 2, 3), "Test 1"),
        ((12, 6, 8, 16), (6, 3, 4, 4), (2, 2, 2, 4), "Test 2"),
        ((20, 14, 36, 18), (5, 7, 6, 9), (4, 2, 6, 2), "Test 3")
    ]
    
    passed = 0
    failed = 0
    
    for i, (t1, t2, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Running {desc}: {t1} / {t2}")
        try:
            await write_arrays(dut, t1, t2)
            
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            await wait_for_done(dut)
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            expected_packed = pack_result(expected)
            
            if result != expected_packed:
                raise TestFailure(
                    f"Expected packed 0x{expected_packed:04X} ({expected}), "
                    f"got 0x{result:04X}"
                )
            
            cocotb.log.info(f"  Result: 0x{result:04X} = {expected}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL {desc}: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")