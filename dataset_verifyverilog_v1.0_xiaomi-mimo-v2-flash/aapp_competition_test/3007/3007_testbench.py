import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

# Constants based on Python problem constraints
MAX_DAYS = 40
MAX_BLING = 16384 # 14 bits sufficient for 100*4000 but spec says 16-bit for safety
MAX_FRUITS = 256  # 8 bits
CLK_NS = 10
MAX_CYCLES = 5000 # Sufficient for 40 days * ~100 cycles/day

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_fruit_farming(dut):
    """Test the Fruit Farming Optimization module"""
    
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        await Timer(CLK_NS * 2, units='ns')
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Define test cases (Input: d, b, f, t0, t1, t2 -> Expected Output)
    test_cases = [
        (4, 0, 1, 0, 0, 0, 300),
        (5, 0, 1, 0, 1, 0, 1900),
        (6, 0, 1, 1, 0, 0, 2300),
        (10, 399, 0, 0, 0, 0, 399),
        (1, 400, 0, 0, 0, 0, 500)
    ]
    
    for i, (d, b, f, t0, t1, t2, expected) in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {i+1}: d={d}, b={b}, f={f}, t0={t0}, t1={t1}, t2={t2}")
        
        # Initialize inputs
        dut.d_in.value = d
        dut.b_in.value = b
        dut.f_in.value = f
        dut.t0_in.value = t0
        dut.t1_in.value = t1
        dut.t2_in.value = t2
        
        # Start signal
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        done = False
        for _ in range(MAX_CYCLES):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break
        
        if not done:
            raise TestFailure(f"Test {i+1} Timeout: Done signal not asserted within {MAX_CYCLES} cycles")
        
        # Check result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i+1} Result signal undefined")
            
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"Test {i+1} Failed: Expected {expected}, got {result}")
        
        cocotb.log.info(f"Test {i+1} Passed: {result}")
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)