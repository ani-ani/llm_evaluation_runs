import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Helper functions

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Reference function for test cases

def find_Index(n):
    if n <= 0:
        return 0
    x = math.sqrt(2 * math.pow(10, (n - 1)))
    return round(x)

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_triangular_index(dut):
    # Setup
    CLK_NS = 10
    MAX_CYCLES = 100
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational design - still need to simulate
        await Timer(10, units='ns')
    
    # Test cases
    test_cases = [
        (2, 4, "2 digits -> index 4"),
        (3, 14, "3 digits -> index 14"),
        (4, 45, "4 digits -> index 45"),
        (1, 1, "1 digit -> index 1 (T(1)=1)"),
        (0, 0, "0 digits -> index 0"),
        (5, 141, "5 digits -> index 141 (T(141)=10011)"),
        (6, 447, "6 digits -> index 447 (T(447)=100128)"),
        (7, 1414, "7 digits -> index 1414"),
        (8, 4472, "8 digits -> index 4472"),
        (9, 14142, "9 digits -> index 14142")
    ]
    
    passed = 0
    failed = 0
    
    for n, exp, desc in test_cases:
        cocotb.log.info(f"Testing {desc}")
        try:
            # Set input n (clamped to 4 bits)
            dut.n.value = clamp_to_width(n, 4)
            
            if is_seq:
                # Start computation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut, MAX_CYCLES)
                
                # Read result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result signal undefined")
                result = int(dut.result.value)
            else:
                # Combinational
                await Timer(10, units='ns')
                result = int(dut.result.value)
            
            # Check result
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result} for n={n}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL test {desc}: {e}")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    
    cocotb.log.info(f"All tests passed: {passed}/{len(test_cases)}")