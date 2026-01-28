import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 32
CLK_NS = 10
MAX_CYCLES = 10000

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

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def set_inputs(dut, y_val, l_val):
    # Split 64-bit y into high and low 32 bits
    y_lsb = clamp_to_width(y_val & 0xFFFFFFFF, 32)
    y_msb = clamp_to_width((y_val >> 32) & 0xFFFFFFFF, 32)
    
    # Split 64-bit l into high and low 32 bits
    l_lsb = clamp_to_width(l_val & 0xFFFFFFFF, 32)
    l_msb = clamp_to_width((l_val >> 32) & 0xFFFFFFFF, 32)
    
    if has_signal(dut, 'y_lsb'): dut.y_lsb.value = y_lsb
    if has_signal(dut, 'y_msb'): dut.y_msb.value = y_msb
    if has_signal(dut, 'l_lsb'): dut.l_lsb.value = l_lsb
    if has_signal(dut, 'l_msb'): dut.l_msb.value = l_msb

async def read_result(dut):
    if not is_value_defined(dut.result_base.value):
        raise TestFailure("Result base undefined")
    result = int(dut.result_base.value)
    return result

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_base_finder(dut):
    # Check for required signals
    required_signals = ['clk', 'rst_n', 'start', 'y_lsb', 'y_msb', 'l_lsb', 'l_msb', 'result_base', 'done']
    for sig in required_signals:
        if not has_signal(dut, sig):
            raise TestFailure(f"Missing required signal: {sig}")
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (y, l, expected_base)
    test_cases = [
        (32, 20, 16),
        (2016, 100, 42),
        (10, 10, 10),  # Base 10, digits [1,0] -> decimal 10 >= 10
        (100, 10, 60), # Base 60: 100 in base 60 = [1,40] -> invalid (40>9)
    ]
    
    passed = 0
    failed = 0
    
    for i, (y, l, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: y={y}, l={l}, expecting base={expected}")
        
        try:
            # Set inputs
            await set_inputs(dut, y, l)
            
            # Pulse start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            result = await read_result(dut)
            
            # Verify
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: Got {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
    
    cocotb.log.info(f"All tests passed: {passed}/{len(test_cases)}")
