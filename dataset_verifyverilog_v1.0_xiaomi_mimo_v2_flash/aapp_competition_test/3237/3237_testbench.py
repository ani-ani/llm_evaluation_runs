import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
RESULT_WIDTH = 64
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# HELPER FUNCTIONS
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
# TESTBENCH
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_min_cost_solver(dut):
    # Detect if sequential (has clk and done)
    is_sequential = has_signal(dut, 'clk') and has_signal(dut, 'done')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Define test cases: (factor_count, primes, exps, expected_min_cost)
    test_cases = [
        # K = 2^2 * 3^1 = 12 -> min cost = 7
        (2, [2, 3, 0, 0], [2, 1, 0, 0], 7),
        # K = 13 * 11 = 143 -> min cost = 24
        (2, [13, 11, 0, 0], [1, 1, 0, 0], 24),
        # K = 11 -> min cost = 12
        (1, [11, 0, 0, 0], [1, 0, 0, 0], 12),
        # Additional test: K = 2^3 = 8 -> min cost = 6
        (1, [2, 0, 0, 0], [3, 0, 0, 0], 6),
        # Additional test: K = 2^1 * 3^1 * 5^1 = 30 -> min cost = 8
        (3, [2, 3, 5, 0], [1, 1, 1, 0], 8),
    ]
    
    passed = 0
    failed = 0
    
    for i, (factor_count, primes, exps, expected) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: factor_count={factor_count}, primes={primes}, exps={exps}")
        
        # Set inputs
        dut.factor_count.value = factor_count
        dut.prime_0.value = primes[0]
        dut.prime_1.value = primes[1]
        dut.prime_2.value = primes[2]
        dut.prime_3.value = primes[3]
        dut.exp_0.value = exps[0]
        dut.exp_1.value = exps[1]
        dut.exp_2.value = exps[2]
        dut.exp_3.value = exps[3]
        
        if is_sequential:
            # Pulse start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            for _ in range(MAX_CYCLES):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    break
            else:
                raise TestFailure(f"Timeout waiting for done in test {i+1}")
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined (X/Z) in test {i+1}")
            result = int(dut.result.value)
        else:
            # Combinational - wait for propagation
            await Timer(100, units='ns')
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined (X/Z) in test {i+1}")
            result = int(dut.result.value)
        
        # Compare
        if result != expected:
            dut._log.error(f"Test {i+1} FAILED: expected {expected}, got {result}")
            failed += 1
        else:
            dut._log.info(f"Test {i+1} PASSED: result = {result}")
            passed += 1
    
    # Summary
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
