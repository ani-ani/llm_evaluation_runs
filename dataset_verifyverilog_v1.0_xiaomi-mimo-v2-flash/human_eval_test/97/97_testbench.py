import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
CLK_NS = 10
MAX_CYCLES = 1000

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

async def wait_for_done(dut, max_cycles=1000):
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

async def calc_expected(a, b):
    """Calculate expected product of unit digits"""
    # Python handles negatives correctly with abs
    unit_a = abs(a) % 10
    unit_b = abs(b) % 10
    return (unit_a * unit_b) & 0xFF  # 8-bit result

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_unit_digit_multiply(dut):
    # Check if sequential or combinational
    is_seq = has_signal(dut, 'clk')
    has_start = has_signal(dut, 'start')
    
    # Setup clock for sequential
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational: no clock, just set inputs
        dut.rst_n.value = 1
        await Timer(10, units='ns')
    
    # Test cases: (a, b, expected_result, description)
    test_cases = [
        (148, 412, 16, "148*412 unit digits (8*2=16)"),
        (19, 28, 72, "19*28 unit digits (9*8=72)"),
        (2020, 1851, 0, "2020*1851 unit digits (0*1=0)"),
        (14, -15, 20, "14*-15 unit digits (4*5=20)"),
        (76, 67, 42, "76*67 unit digits (6*7=42)"),
        (17, 27, 49, "17*27 unit digits (7*7=49)"),
        (0, 1, 0, "0*1 unit digits (0*1=0)"),
        (0, 0, 0, "0*0 unit digits (0*0=0)"),
        (-5, -3, 15, "-5*-3 unit digits (5*3=15)"),
        (-99, 99, 1, "-99*99 unit digits (9*9=81) -> 81"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (a, b, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        try:
            # Convert to signed 8-bit for HDL
            a_signed = to_signed(a, DATA_WIDTH) & 0xFF
            b_signed = to_signed(b, DATA_WIDTH) & 0xFF
            
            # Set inputs
            dut.a.value = a_signed
            dut.b.value = b_signed
            
            if is_seq:
                # Sequential: start pulse
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational: wait for propagation
                await Timer(100, units='ns')
            
            # Check result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result} (a={a}, b={b})")
            
            passed += 1
            cocotb.log.info(f"  PASS: result = {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    else:
        cocotb.log.info(f"All {passed} tests passed!")
