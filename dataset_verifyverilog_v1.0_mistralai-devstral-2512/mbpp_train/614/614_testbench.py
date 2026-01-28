import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH, SUM_WIDTH, CLK_NS, MAX_CYCLES = 8, 16, 10, 64

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

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
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_array(dut, name, vals, width, max_len):
    """Write individual elements to array"""
    for i in range(min(len(vals), max_len)):
        getattr(dut, f"{name}_{i}").value = clamp_to_width(vals[i], width)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_cummulative_sum(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(10, units='ns')
    
    # Test cases: (tuple_count, tuple_lengths, values, expected_sum, description)
    test_cases = [
        (3, [2, 3, 2], [1, 3, 5, 6, 7, 2, 6, 0, 0, 0, 0, 0], 30, "(1,3),(5,6,7),(2,6)"),
        (3, [2, 3, 2], [2, 4, 6, 7, 8, 3, 7, 0, 0, 0, 0, 0], 37, "(2,4),(6,7,8),(3,7)"),
        (3, [2, 3, 2], [3, 5, 7, 8, 9, 4, 8, 0, 0, 0, 0, 0], 44, "(3,5),(7,8,9),(4,8)")
    ]
    
    passed = failed = 0
    
    for i, (tcount, tlengths, vals, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Write inputs
            if has_signal(dut, 'tuple_count'):
                dut.tuple_count.value = tcount
            
            # Write tuple lengths
            for j in range(3):
                if has_signal(dut, f'tuple_lengths_{j}'):
                    getattr(dut, f'tuple_lengths_{j}').value = clamp_to_width(tlengths[j], 3)
            
            # Write values array (12 elements)
            for j in range(12):
                if has_signal(dut, f'values_{j}'):
                    getattr(dut, f'values_{j}').value = clamp_to_width(vals[j], 8)
            
            # Start computation
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}"); failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {len(test_cases)}")