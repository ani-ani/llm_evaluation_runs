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

# Constants
DATA_WIDTH = 8
MAX_CYCLES = 100
CLK_NS = 10

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_is_sum_of_powers_of_two(dut):
    # Check if module has sequential signals
    is_seq = has_signal(dut, 'clk') and has_signal(dut, 'start')
    
    if is_seq:
        # Setup clock and reset
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational mode - no clock needed
        await Timer(100, units='ns')
    
    # Test cases: (input_n, expected_result, description)
    test_cases = [
        (10, 1, "10 is even (1010) -> sum of powers of 2"),
        (7, 0, "7 is odd (0111) -> NOT sum of powers of 2"),
        (14, 1, "14 is even (1110) -> sum of powers of 2"),
        (2, 1, "2 is even (0010) -> 2^1"),
        (1, 0, "1 is odd (0001) -> can be represented but problem says only even"),
        (0, 1, "0 is even (0000) -> sum of zero powers"),
        (255, 0, "255 is odd (11111111) -> NOT"),
        (254, 1, "254 is even (11111110) -> sum of powers"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n_val, exp_result, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Clamp input to 8 bits
            n_clamped = clamp_to_width(n_val, DATA_WIDTH)
            dut.n.value = n_clamped
            
            if is_seq:
                # Sequential mode: trigger with start
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut, MAX_CYCLES)
                
                # Check result when done
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined after done")
                result = int(dut.result.value)
            else:
                # Combinational mode: just wait for settle
                await Timer(10, units='ns')
                
                # Check valid signal if exists
                if has_signal(dut, 'valid'):
                    if not is_value_defined(dut.valid.value):
                        raise TestFailure("Valid signal undefined")
                    if int(dut.valid.value) != 1:
                        raise TestFailure("Valid signal not high")
                
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                result = int(dut.result.value)
            
            # Validate result
            if result != exp_result:
                raise TestFailure(f"Expected {exp_result}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: n={n_clamped} -> result={result}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\nTest Summary: {passed} passed, {failed} failed")
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_edge_cases(dut):
    # Additional edge case testing
    is_seq = has_signal(dut, 'clk') and has_signal(dut, 'start')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
    
    # Test boundary: 0 and 255
    test_cases = [
        (0, 1, "Zero edge case"),
        (255, 0, "Max odd value"),
        (254, 1, "Max even value"),
    ]
    
    for n_val, exp, desc in test_cases:
        dut.n.value = clamp_to_width(n_val, DATA_WIDTH)
        
        if is_seq:
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut)
            result = int(dut.result.value)
        else:
            await Timer(10, units='ns')
            result = int(dut.result.value)
        
        if result != exp:
            raise TestFailure(f"Edge case {desc}: expected {exp}, got {result}")
        
        cocotb.log.info(f"{desc}: PASS")
