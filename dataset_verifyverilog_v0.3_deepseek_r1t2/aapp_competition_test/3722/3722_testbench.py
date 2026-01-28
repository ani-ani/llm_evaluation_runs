import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# EXPECTED RESULT FUNCTION (matches problem logic)
# ============================================================================

def expected_result(N, c_AA, c_AB, c_BA, c_BB, mod=10**9+7):
    # Convert to rule string
    rule = (c_AA, c_AB, c_BA, c_BB)
    
    # Type 1 rules: always 1
    type1 = set([
        (0,0,0,0), (0,0,0,1), (0,0,1,0), (0,0,1,1),
        (0,1,0,1), (0,1,1,1), (1,1,0,1), (1,1,1,1)
    ])
    
    # Type 2 rules: 2^(N-3)
    type2 = set([
        (0,1,0,0), (1,0,1,0), (1,0,1,1), (1,1,0,0)
    ])
    
    # Type 3 rules: Fibonacci
    type3 = set([
        (0,1,1,0), (1,0,0,0), (1,0,0,1), (1,1,1,0)
    ])
    
    if rule in type1:
        return 1
    elif rule in type2:
        if N <= 2:
            return 1
        return pow(2, N-3, mod)
    else:  # type3
        if N <= 3:
            return 1
        a, b = 1, 1
        for _ in range(4, N+1):
            a, b = b, (a + b) % mod
        return b

# ============================================================================
# TESTBENCH
# ============================================================================

@cocotb.test(timeout_time=100, timeout_unit="ms")
async def test_snuke_counter(dut):
    """Test snuke_string_counter for various rules and N values"""
    
    # Setup clock (10ns period)
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Comprehensive test cases covering all rule types
    test_cases = [
        # (N, c_AA, c_AB, c_BA, c_BB, expected)
        # Type 1 (always 1)
        (2, 0,0,0,0, 1),  # AAAA
        (3, 0,0,0,0, 1),
        (16, 0,0,0,0, 1),
        (5, 1,1,0,1, 1),  # BBAB
        (10, 0,1,1,1, 1), # ABBB
        
        # Type 2 (2^(N-3))
        (4, 0,1,0,0, 2),  # ABAA -> 2^(1) = 2
        (5, 0,1,0,0, 4),  # ABAA -> 2^(2) = 4
        (6, 0,1,0,0, 8),  # ABAA -> 2^(3) = 8
        (4, 1,0,1,0, 2),  # BABA
        (7, 1,0,1,1, 16), # BABB -> 2^(4) = 16
        (16, 1,1,0,0, 4096), # BBAA -> 2^(13) = 8192 (mod 10^9+7 = 8192)
        
        # Type 3 (Fibonacci)
        (4, 0,1,1,0, 2),  # ABBA -> Fib(4) = 2
        (5, 0,1,1,0, 3),  # ABBA -> Fib(5) = 3
        (6, 0,1,1,0, 5),  # ABBA -> Fib(6) = 5
        (4, 1,0,0,0, 2),  # BAAA
        (5, 1,0,0,0, 3),  # BAAA
        (6, 1,0,0,0, 5),  # BAAA
        (16, 0,1,1,0, 987),  # ABBA -> Fib(16)=987
        (16, 1,0,0,0, 987),  # BAAA -> Fib(16)=987
        
        # Edge cases
        (2, 0,1,1,0, 1),  # N=2, ABBA
        (3, 0,1,1,0, 1),  # N=3, ABBA
        (2, 0,1,0,0, 1),  # N=2, ABAA
        (3, 1,0,1,0, 1),  # N=3, BABA
        (2, 1,1,0,0, 1),  # N=2, BBAA
        (3, 1,1,0,0, 1),  # N=3, BBAA
    ]
    
    passed = 0
    failed = 0
    
    for i, (N, c_AA, c_AB, c_BA, c_BB, expected) in enumerate(test_cases):
        # Log test
        dut._log.info(f"Test {i+1}: N={N}, rules={c_AA}{c_AB}{c_BA}{c_BB}, expected={expected}")
        
        # Set inputs
        dut.N.value = N
        dut.c_AA.value = c_AA
        dut.c_AB.value = c_AB
        dut.c_BA.value = c_BA
        dut.c_BB.value = c_BB
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (with cycle timeout)
        cycles = 0
        max_cycles = 50  # Plenty for worst-case (16 Fibonacci)
        while cycles < max_cycles:
            await RisingEdge(dut.clk)
            cycles += 1
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        else:
            dut._log.error(f"Test {i+1}: Timeout after {max_cycles} cycles")
            failed += 1
            continue
        
        # Read result
        if not is_value_defined(dut.result.value):
            dut._log.error(f"Test {i+1}: Result undefined")
            failed += 1
            continue
            
        result = int(dut.result.value)
        
        # Verify
        if result != expected:
            dut._log.error(f"Test {i+1} FAILED: Expected {expected}, got {result}")
            failed += 1
        else:
            dut._log.info(f"Test {i+1}: PASS")
            passed += 1
        
        # Wait for next test
        await RisingEdge(dut.clk)
    
    # Summary
    dut._log.info(f"\n{'='*50}")
    dut._log.info(f"Test Summary: {passed}/{len(test_cases)} passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_reset_behavior(dut):
    """Test that reset properly clears state"""
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Start in middle of computation
    dut.N.value = 16
    dut.c_AA.value = 0
    dut.c_AB.value = 1
    dut.c_BA.value = 1
    dut.c_BB.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait a few cycles
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    
    # Assert reset
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    # Should be back to IDLE
    await RisingEdge(dut.clk)
    
    # Verify done is low and result is 0
    if int(dut.done.value) != 0:
        raise TestFailure("Reset failed: done not cleared")
    
    if int(dut.result.value) != 0:
        raise TestFailure("Reset failed: result not cleared")
    
    # Now run full computation to verify it works after reset
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    cycles = 0
    while not (is_value_defined(dut.done.value) and int(dut.done.value) == 1):
        await RisingEdge(dut.clk)
        cycles += 1
        if cycles > 30:
            raise TestFailure("Computation after reset timed out")
    
    # Result should be 987 for N=16, ABBA
    result = int(dut.result.value)
    if result != 987:
        raise TestFailure(f"Post-reset computation failed: expected 987, got {result}")
    
    dut._log.info("Reset behavior test passed")
