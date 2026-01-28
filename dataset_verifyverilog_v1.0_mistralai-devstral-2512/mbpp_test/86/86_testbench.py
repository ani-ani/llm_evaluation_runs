import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except (ValueError, TypeError): return False

def safe_int(v, default=0):
    try: return int(v)
    except (ValueError, TypeError): return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    if v < 0: return 0
    return min((1 << bits) - 1, v)

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=100, timeout_unit="ms")
async def test_centered_hexagonal(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (n, expected_result)
    test_cases = [
        (1, 1),
        (2, 7),
        (9, 217),
        (10, 271),
        (1, 1)  # Repeat to verify reset behavior
    ]
    
    for i, (n_val, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={n_val}")
        
        # Set input
        dut.n.value = n_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Test {i+1}: Result undefined")
            
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"Test {i+1}: Expected {expected}, got {result}")
        
        cocotb.log.info(f"  PASS: Result={result}")
        
        # Reset before next test
        await reset_dut(dut)
        
    cocotb.log.info("All tests passed!")
