import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 32
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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_opposite_signs(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (x, y, expected_result, description)
    test_cases = [
        (1, -2, 1, "1 and -2 are opposite"),
        (3, 2, 0, "3 and 2 are same sign (positive)"),
        (-10, -10, 0, "-10 and -10 are same sign (negative)"),
        (-2, 2, 1, "-2 and 2 are opposite"),
        (0, 0, 0, "0 and 0 (both zero)"),
        (0, -1, 1, "0 and -1 (zero and negative)"),
        (5, -5, 1, "5 and -5 are opposite"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (x_val, y_val, exp_result, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Convert to unsigned for assignment
            x_unsigned = from_signed(x_val, DATA_WIDTH)
            y_unsigned = from_signed(y_val, DATA_WIDTH)
            
            # Assign inputs
            dut.x.value = x_unsigned
            dut.y.value = y_unsigned
            
            # Trigger computation
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done signal
                await wait_for_done(dut, MAX_CYCLES)
            else:
                # Combinational - wait for propagation
                await Timer(100, units='ns')
            
            # Check result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            if result != exp_result:
                raise TestFailure(f"Expected {exp_result}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: result={result}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} out of {passed+failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed")