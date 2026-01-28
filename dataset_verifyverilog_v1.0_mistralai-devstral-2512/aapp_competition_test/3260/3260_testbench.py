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

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    if bits >= 32: return v & 0xFFFFFFFF
    return min((1 << bits) - 1, max(0, v))

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_permutation_runs(dut):
    # Check signals
    has_clk = has_signal(dut, 'clk')
    has_rst = has_signal(dut, 'rst_n')
    has_start = has_signal(dut, 'start')
    has_done = has_signal(dut, 'done')
    has_result = has_signal(dut, 'result')
    
    if not all([has_clk, has_rst, has_start, has_done, has_result]):
        cocotb.log.error("Missing required signals")
        raise TestFailure("Module missing required signals")
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Test cases
    test_cases = [
        (1, 7, 1000000007, 1),
        (3, 2, 1000000007, 4),
        (9, 3, 1000000009, 224458)
    ]
    
    for i, (n_val, k_val, p_val, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={n_val}, k={k_val}, p={p_val}")
        
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Set inputs
        dut.n.value = clamp_to_width(n_val, 8)
        dut.k.value = clamp_to_width(k_val, 3)
        dut.p.value = clamp_to_width(p_val, 32)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        done = False
        for _ in range(2000):  # Max cycles
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break
        
        if not done:
            raise TestFailure(f"Test {i+1}: Timeout waiting for done")
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i+1}: Result undefined")
        
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"Test {i+1}: Expected {expected}, got {result}")
        
        cocotb.log.info(f"Test {i+1}: PASS")
        
        # Small delay between tests
        await Timer(100, units='ns')
    
    cocotb.log.info("All tests passed!")