import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
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

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_convex_score(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (N, [x0..x7], [y0..y7], expected_result)
    test_cases = [
        (4, [0,0,1,1,0,0,0,0], [0,1,0,1,0,0,0,0], 5),
        (5, [0,0,0,0,1,0,0,0], [0,1,2,3,1,0,0,0], 11),
        (1, [3141,0,0,0,0,0,0,0], [2718,0,0,0,0,0,0,0], 0),
        (2, [11,31,0,0,0,0,0,0], [22,45,0,0,0,0,0,0], 0),
        (3, [0,9998,9997,0,0,0,0,0], [0,9999,9998,0,0,0,0,0], 1),
    ]
    
    for N, xs, ys, expected in test_cases:
        dut._log.info(f"Testing N={N}, expected={expected}")
        
        # Set N and points
        dut.N.value = N
        for i in range(8):
            setattr(dut, f'x{i}', xs[i])
            setattr(dut, f'y{i}', ys[i])
        
        # Start computation
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        cycles = 0
        while True:
            if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
            await RisingEdge(dut.clk)
            cycles += 1
            if cycles > 500:
                raise TestFailure(f"Timeout for N={N}")
        
        # Check result
        result = safe_int(dut.result.value)
        if result != expected:
            raise TestFailure(f"N={N}: expected {expected}, got {result}")
        
        dut._log.info(f"N={N}: PASS (result={result})")
    
    dut._log.info("All tests passed!")

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False