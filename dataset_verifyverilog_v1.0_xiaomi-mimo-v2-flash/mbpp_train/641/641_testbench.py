import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, v))

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Nonagonal formula: n * (7*n - 5) / 2
def compute_nonagonal(n):
    return int(n * (7 * n - 5) / 2)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_nonagonal(dut):
    # Setup clock
    CLK_NS = 10
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        (10, 325, "n=10"),
        (15, 750, "n=15"),
        (18, 1089, "n=18"),
        (1, 1, "n=1"),
        (0, 0, "n=0"),
        (255, compute_nonagonal(255), "n=255")
    ]
    
    passed = 0
    failed = 0
    
    for n_input, expected, desc in test_cases:
        cocotb.log.info(f"Testing {desc}: n={n_input}, expected={expected}")
        
        # Set input
        dut.n.value = clamp_to_width(n_input, 8)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        try:
            await wait_for_done(dut, max_cycles=50)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result signal undefined for {desc}")
            
            result = int(dut.result.value)
            
            # Verify
            if result != expected:
                raise TestFailure(
                    f"Mismatch for {desc}: expected {expected}, got {result}"
                )
            
            passed += 1
            cocotb.log.info(f"  PASS: {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Small delay before next test
        await RisingEdge(dut.clk)
    
    # Summary
    if failed:
        raise TestFailure(f"{failed} out of {passed + failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed!")