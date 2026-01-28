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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=300):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def read_ludic_result(dut):
    if not has_signal(dut, 'result_data_0'):
        raise TestFailure("Missing result_data ports")
    count = safe_int(dut.result_count.value)
    result = []
    for i in range(10):
        port = getattr(dut, f'result_data_{i}')
        val = safe_int(port.value)
        if i < count:
            result.append(val)
    return result

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_ludic(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        (10, [1, 2, 3, 5, 7]),
        (25, [1, 2, 3, 5, 7, 11, 13, 17, 23, 25]),
        (45, [1, 2, 3, 5, 7, 11, 13, 17, 23, 25, 29, 37, 41, 43])
    ]
    
    passed = 0
    failed = 0
    
    for i, (n_input, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={n_input}")
        try:
            dut.n.value = clamp_to_width(n_input, 4)
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            await wait_for_done(dut)
            
            result = await read_ludic_result(dut)
            
            if len(result) != len(expected):
                raise TestFailure(f"Count mismatch: expected {len(expected)}, got {len(result)}")
            
            for j, (e, r) in enumerate(zip(expected, result)):
                if r != e:
                    raise TestFailure(f"Index {j}: expected {e}, got {r}")
            
            passed += 1
            cocotb.log.info(f"PASS: {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL Test {i+1}: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")