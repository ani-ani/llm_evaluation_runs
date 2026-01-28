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

async def write_array(dut, name, vals, width):
    for i, v in enumerate(vals):
        if i < 16:  # Maximum array size
            signed_val = from_signed(v, width)
            getattr(dut, name)[i].value = clamp_to_width(signed_val, width)

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=256):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_double_the_difference(dut):
    DATA_WIDTH, MAX_LEN, CLK_NS = 8, 16, 10
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (input_list, expected_sum, description)
    test_cases = [
        ([1, 3, 2, 0], 10, "Basic case from description"),
        ([], 0, "Empty list"),
        ([5, 4], 25, "Single odd positive"),
        ([0.1, 0.2, 0.3], 0, "Floats (truncated to 0)"),
        ([-10, -20, -30], 0, "All negative"),
        ([-1, -2, 8], 0, "Negative and positive even"),
        ([0.2, 3, 5], 34, "Float with odd positives"),
        (list(range(-99, 100, 2)), sum(i**2 for i in range(-99, 100, 2) if i > 0 and i % 2 != 0), "Large range")
    ]
    
    passed = failed = 0
    
    for i, (inp, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Truncate floats to integers for HDL simulation
            int_inp = [int(v) for v in inp]
            
            # Write inputs
            await write_array(dut, 'arr', int_inp, DATA_WIDTH)
            dut.len.value = clamp_to_width(len(inp), 4)
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for completion
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            
            # Compare (use 16-bit to handle 99^2 = 9801 fits in 16-bit)
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")