import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
N = 4
CLK_PERIOD_NS = 10
MAX_CYCLES = 256
L_ASCII = 76
R_ASCII = 82

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_circle_dance(dut):
    is_sequential = has_signal(dut, 'clk') and has_signal(dut, 'done')
    
    if is_sequential:
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        ([1, 1, 1, 1], "LLLL", "All ones"),
        ([1, 2, 3, 0], None, "No solution"),
        ([0, 0, 0, 0], "LLLL", "All zeros"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (p_values, expected_str, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            for j, p_val in enumerate(p_values):
                port_name = f'p_{j}'
                if has_signal(dut, port_name):
                    getattr(dut, port_name).value = clamp_to_width(p_val, DATA_WIDTH)
                else:
                    raise TestFailure(f"Signal {port_name} not found")
            
            if is_sequential:
                await start_computation(dut)
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            if not is_value_defined(dut.valid.value):
                raise TestFailure("valid signal is undefined (X/Z)")
            
            valid = int(dut.valid.value)
            
            if expected_str is None:
                if valid == 0:
                    cocotb.log.info(f"  PASS: Correctly output 'no dance' (valid=0)")
                    passed += 1
                else:
                    raise TestFailure(f"Expected valid=0, got valid={valid}")
            else:
                if valid != 1:
                    raise TestFailure(f"Expected valid=1, got valid={valid}")
                
                result_chars = []
                for j in range(N):
                    port_name = f'result_{j}'
                    if has_signal(dut, port_name):
                        char_val = getattr(dut, port_name).value
                        if is_value_defined(char_val):
                            result_chars.append(chr(int(char_val)))
                        else:
                            result_chars.append('?')
                    else:
                        raise TestFailure(f"Signal {port_name} not found")
                
                result_str = ''.join(result_chars)
                
                if result_str != expected_str:
                    raise TestFailure(f"Expected '{expected_str}', got '{result_str}'")
                
                cocotb.log.info(f"  PASS: result = '{result_str}'")
                passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")