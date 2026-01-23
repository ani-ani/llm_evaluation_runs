import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_optimize_friends(dut):
    """Test the optimize_friends module"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (n, [p0..p7], expected_output)
    # Note: probabilities are given as floats, we convert to 16-bit fixed-point Q0.16
    # Q0.16: value * 65536, then take integer part
    test_cases = [
        (4, [0.1, 0.2, 0.3, 0.8], 0.8),
        (2, [0.1, 0.2], 0.26),
        (1, [0.217266], 0.217266),
        (2, [0.608183, 0.375030], 0.608183),
        (3, [0.388818, 0.399762, 0.393874], 0.478724284024),
        (4, [0.801024, 0.610878, 0.808545, 0.732504], 0.808545),
        (5, [0.239482, 0.686259, 0.543226, 0.764939, 0.401318], 0.764939),
        (6, [0.462434, 0.775020, 0.479749, 0.373861, 0.492031, 0.746333], 0.775020),
        (7, [0.745337, 0.892271, 0.792853, 0.892917, 0.768246, 0.901623, 0.815793], 0.901623),
        (1, [0.057695], 0.057695),
        (2, [0.057750, 0.013591], 0.0697712395),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, probs, expected) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: n={n}, probs={probs}, expected={expected}")
        
        # Convert probabilities to 16-bit fixed-point Q0.16
        probs_fixed = []
        for p in probs:
            fixed_val = int(p * 65536)
            if fixed_val > 65535:
                fixed_val = 65535
            probs_fixed.append(fixed_val)
        
        # Pad to 8 probabilities
        while len(probs_fixed) < 8:
            probs_fixed.append(0)
        
        # Set inputs
        dut.n.value = n
        dut.p0.value = probs_fixed[0]
        dut.p1.value = probs_fixed[1]
        dut.p2.value = probs_fixed[2]
        dut.p3.value = probs_fixed[3]
        dut.p4.value = probs_fixed[4]
        dut.p5.value = probs_fixed[5]
        dut.p6.value = probs_fixed[6]
        dut.p7.value = probs_fixed[7]
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.result.value):
            dut._log.error(f"Test {i+1}: Result is undefined")
            failed += 1
            continue
            
        result_raw = int(dut.result.value)
        # Convert result from Q0.32 to float
        result_float = result_raw / (2**32)
        
        # Compare with expected
        if abs(result_float - expected) < 1e-6:
            dut._log.info(f"Test {i+1}: PASS - result={result_float:.9f}")
            passed += 1
        else:
            dut._log.error(f"Test {i+1}: FAIL - expected {expected:.9f}, got {result_float:.9f}")
            failed += 1
        
        # Reset between tests
        await reset_dut(dut)
    
    # Summary
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")