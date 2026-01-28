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

# Wait for done signal
async def wait_for_done(dut, max_cycles=200):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Reset DUT
async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Calculate expected result
def calculate_expected(x, y):
    if x > y:
        return -1  # Represented as 16'hFFFF
    if y % 2 == 0:
        return y
    if x == y:
        return -1
    return y - 1

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_choose_num(dut):
    # Setup clock
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
    
    # Test cases
    test_cases = [
        (12, 15, 14, "even y"),
        (13, 12, -1, "x > y"),
        (33, 12354, 12354, "even large y"),
        (5234, 5233, -1, "x > y large"),
        (6, 29, 28, "odd y, even x"),
        (27, 10, -1, "x > y, small"),
        (7, 7, -1, "single odd"),
        (546, 546, 546, "single even"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (x_val, y_val, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} (x={x_val}, y={y_val})")
        try:
            # Set inputs
            if has_signal(dut, 'x'):
                dut.x.value = clamp_to_width(x_val, 16)
            if has_signal(dut, 'y'):
                dut.y.value = clamp_to_width(y_val, 16)
            
            # Start computation
            if is_seq:
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
            
            # Convert -1 (0xFFFF) to Python -1
            if result == 0xFFFF:
                result = -1
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: result={result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
    
    cocotb.log.info(f"All {passed} tests passed")