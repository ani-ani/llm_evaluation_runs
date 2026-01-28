import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH, ARRAY_SIZE, CLK_NS, MAX_CYCLES = 16, 16, 10, 5000

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

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_array(dut, name, vals, width, max_len=16):
    for i, v in enumerate(vals[:max_len]):
        getattr(dut, name)[i].value = clamp_to_width(v, width)

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_max_subrectangle(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        # n, m, a, b, x, expected_area
        (3, 3, [1, 2, 3], [1, 2, 3], 9, 4),
        (5, 1, [5, 4, 2, 4, 5], [2], 5, 1),
        (1, 1, [1], [1], 1, 1),
        (2, 2, [1, 1], [1, 1], 4, 4),
        (4, 4, [2, 2, 2, 2], [2, 2, 2, 2], 10, 16),
    ]
    
    passed = failed = 0
    
    for i, (n_val, m_val, a_vals, b_vals, x_val, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={n_val}, m={m_val}, x={x_val}")
        try:
            if is_seq:
                # Set inputs
                dut.n.value = clamp_to_width(n_val, 4)
                dut.m.value = clamp_to_width(m_val, 4)
                dut.x.value = clamp_to_width(x_val, 32)
                await write_array(dut, 'a', a_vals, DATA_WIDTH)
                await write_array(dut, 'b', b_vals, DATA_WIDTH)
                
                # Start
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut)
                
                # Check result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                result = int(dut.result.value)
                
                if result != expected:
                    raise TestFailure(f"Expected {expected}, got {result}")
                passed += 1
            else:
                # Combinational - set inputs
                dut.n.value = clamp_to_width(n_val, 4)
                dut.m.value = clamp_to_width(m_val, 4)
                dut.x.value = clamp_to_width(x_val, 32)
                await write_array(dut, 'a', a_vals, DATA_WIDTH)
                await write_array(dut, 'b', b_vals, DATA_WIDTH)
                await Timer(100, units='ns')
                
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                result = int(dut.result.value)
                
                if result != expected:
                    raise TestFailure(f"Expected {expected}, got {result}")
                passed += 1
                
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")