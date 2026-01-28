import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Constants
DATA_WIDTH = 8  # 8-bit unsigned radius
RESULT_WIDTH = 24  # 24-bit signed result in Q16.16
CLK_NS = 10
MAX_CYCLES = 10

# Fixed-point constants
PI_FIXED = 205887  # 3.141592653589793 * 65536

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    if v < 0:
        return -((-v) & max_val)
    return min(max_val, max(0, v))

async def reset_dut(dut, cycles=2):
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        for _ in range(cycles):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        # Asynchronous reset or none
        await Timer(10, units='ns')

@cocotb.test(timeout_time=1000, timeout_unit='ms')
async def test_circle_circumference(dut):
    # Check if sequential module
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Define test cases: (radius, expected_circumference, description)
    test_cases = [
        (10, 628300, "Radius 10"),
        (5, 314150, "Radius 5"),
        (4, 251320, "Radius 4"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (radius, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            if is_seq:
                # Apply radius and start
                dut.radius.value = clamp_to_width(radius, DATA_WIDTH)
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                if has_signal(dut, 'done'):
                    done_received = False
                    for _ in range(MAX_CYCLES):
                        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                            done_received = True
                            break
                        await RisingEdge(dut.clk)
                    if not done_received:
                        raise TestFailure(f"Done not asserted after {MAX_CYCLES} cycles")
                else:
                    # No done signal, assume immediate
                    await Timer(10, units='ns')
            else:
                # Combinational: set inputs and wait
                dut.radius.value = clamp_to_width(radius, DATA_WIDTH)
                await Timer(10, units='ns')
            
            # Read result
            if not is_value_defined(dut.circumference.value):
                raise TestFailure("Result undefined")
            
            result_raw = int(dut.circumference.value)
            # Convert to signed if negative
            if result_raw >= (1 << (RESULT_WIDTH - 1)):
                result = result_raw - (1 << RESULT_WIDTH)
            else:
                result = result_raw
            
            # Convert Q16.16 to float for comparison
            result_float = result / 65536.0
            expected_float = expected / 65536.0
            
            # Check with tolerance
            if not math.isclose(result_float, expected_float, rel_tol=0.001):
                raise TestFailure(f"Expected {expected_float:.6f}, got {result_float:.6f}")
            
            passed += 1
            cocotb.log.info(f"  PASS: radius={radius}, result={result_float:.6f}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")