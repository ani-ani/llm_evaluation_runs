import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure

# Helper function to check if a value is defined (not X or Z)
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

# Helper function to wait for done signal with cycle timeout
async def wait_for_done(dut, max_cycles=30):
    """Wait for done signal to go high, with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            return True
    return False

@cocotb.test(timeout_time=500, timeout_unit='ms')
async def test_fib4_basic(dut):
    """Test Fib4 with basic values including base cases."""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    await clock.start()
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.n.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (n, expected)
    test_cases = [
        (0, 0),   # fib4(0) = 0
        (1, 0),   # fib4(1) = 0
        (2, 2),   # fib4(2) = 2
        (3, 0),   # fib4(3) = 0
        (4, 2),   # fib4(4) = 2 (0+0+2+0)
        (5, 4),   # fib4(5) = 4 (0+2+0+2)
        (6, 8),   # fib4(6) = 8 (2+0+2+4)
        (7, 14),  # fib4(7) = 14 (0+2+4+8)
        (8, 28),  # fib4(8) = 28 (2+4+8+14)
        (10, 104), # fib4(10) = 104
        (12, 386), # fib4(12) = 386
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n, expected in test_cases:
        # Set inputs
        dut.n.value = n
        await RisingEdge(dut.clk)
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (with timeout per test)
        done_ok = await wait_for_done(dut, max_cycles=25)
        
        if not done_ok:
            dut._log.error(f'Test n={n}: Timeout waiting for done signal')
            continue
        
        # Check result is defined
        if not is_value_defined(dut.result.value):
            dut._log.error(f'Test n={n}: Result is undefined (X/Z)')
            continue
        
        result = int(dut.result.value)
        if result == expected:
            dut._log.info(f'Test n={n}: PASSED (result={result})')
            passed += 1
        else:
            dut._log.error(f'Test n={n}: FAILED - expected {expected}, got {result}')
    
    dut._log.info(f'Summary: {passed}/{total} tests passed')
    if passed != total:
        raise TestFailure(f'Only {passed} out of {total} tests passed')

@cocotb.test(timeout_time=500, timeout_unit='ms')
async def test_fib4_iterations(dut):
    """Test that Fib4 computes correctly for iterative cases."""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    await clock.start()
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases for higher iterations
    test_cases = [
        (15, 2224),  # fib4(15) = 2224 (calculated from sequence)
        (11, 206),   # fib4(11) = 206
        (9, 52),     # fib4(9) = 52
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n, expected in test_cases:
        dut.n.value = n
        await RisingEdge(dut.clk)
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done with extended timeout for larger n
        done_ok = await wait_for_done(dut, max_cycles=30)
        
        if not done_ok:
            dut._log.error(f'Test n={n}: Timeout')
            continue
        
        if not is_value_defined(dut.result.value):
            dut._log.error(f'Test n={n}: Undefined result')
            continue
        
        result = int(dut.result.value)
        if result == expected:
            dut._log.info(f'Test n={n}: PASSED (result={result})')
            passed += 1
        else:
            dut._log.error(f'Test n={n}: FAILED - expected {expected}, got {result}')
    
    dut._log.info(f'Summary: {passed}/{total} tests passed')
    if passed != total:
        raise TestFailure(f'Only {passed} out of {total} tests passed')

@cocotb.test(timeout_time=500, timeout_unit='ms')
async def test_fib4_sequence_completeness(dut):
    """Verify the full sequence is correct by checking consecutive values."""
    clock = Clock(dut.clk, 10, units='ns')
    await clock.start()
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Precomputed correct sequence values
    # fib4: [0, 0, 2, 0, 2, 4, 8, 14, 28, 52, 104, 206, 386, 724, 1360, 2224]
    correct_sequence = [0, 0, 2, 0, 2, 4, 8, 14, 28, 52, 104, 206, 386, 724, 1360, 2224]
    
    passed = 0
    total = min(len(correct_sequence), 16)
    
    for n in range(total):
        expected = correct_sequence[n]
        
        dut.n.value = n
        await RisingEdge(dut.clk)
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        done_ok = await wait_for_done(dut, max_cycles=25)
        
        if not done_ok:
            dut._log.error(f'Sequence index {n}: Timeout')
            continue
        
        if not is_value_defined(dut.result.value):
            dut._log.error(f'Sequence index {n}: Undefined result')
            continue
        
        result = int(dut.result.value)
        if result == expected:
            passed += 1
        else:
            dut._log.error(f'Sequence index {n}: expected {expected}, got {result}')
            # Show sequence context
            if n > 0:
                dut._log.info(f'  Previous values (n-2 to n-1): {correct_sequence[n-2:n]}')
    
    dut._log.info(f'Sequence verification: {passed}/{total} values correct')
    if passed != total:
        raise TestFailure(f'Sequence incomplete: {passed}/{total}')

@cocotb.test(timeout_time=500, timeout_unit='ms')
async def test_fib4_edge_cases(dut):
    """Test edge cases and boundary conditions."""
    clock = Clock(dut.clk, 10, units='ns')
    await clock.start()
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Edge cases
    edge_cases = [
        (0, 0, 'Minimum n'),
        (1, 0, 'n=1'),
        (2, 2, 'n=2 base case'),
        (3, 0, 'n=3 base case'),
        (4, 2, 'First iterative case'),
        (16, 366880, 'Maximum n in range'),
    ]
    
    passed = 0
    total = len(edge_cases)
    
    for n, expected, description in edge_cases:
        dut.n.value = n
        await RisingEdge(dut.clk)
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        done_ok = await wait_for_done(dut, max_cycles=35)
        
        if not done_ok:
            dut._log.error(f"Edge case '{description}': Timeout")
            continue
        
        if not is_value_defined(dut.result.value):
            dut._log.error(f"Edge case '{description}': Undefined result")
            continue
        
        result = int(dut.result.value)
        if result == expected:
            dut._log.info(f"Edge case '{description}': PASSED")
            passed += 1
        else:
            dut._log.error(f"Edge case '{description}': expected {expected}, got {result}")
    
    dut._log.info(f'Edge cases: {passed}/{total} passed')
    if passed != total:
        raise TestFailure(f'Edge cases failed: {passed}/{total}')

@cocotb.test(timeout_time=500, timeout_unit='ms')
async def test_fib4_sequential_correctness(dut):
    """Test sequential execution - multiple calculations back-to-back."""
    clock = Clock(dut.clk, 10, units='ns')
    await clock.start()
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Sequential test cases
    test_cases = [
        (5, 4),
        (6, 8),
        (7, 14),
        (8, 28),
        (9, 52),
        (10, 104),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for n, expected in test_cases:
        dut.n.value = n
        await RisingEdge(dut.clk)
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        done_ok = await wait_for_done(dut, max_cycles=25)
        
        if not done_ok:
            dut._log.error(f'Sequential test n={n}: Timeout')
            continue
        
        if not is_value_defined(dut.result.value):
            dut._log.error(f'Sequential test n={n}: Undefined result')
            continue
        
        result = int(dut.result.value)
        if result == expected:
            passed += 1
        else:
            dut._log.error(f'Sequential test n={n}: expected {expected}, got {result}')
    
    dut._log.info(f'Sequential tests: {passed}/{total} passed')
    if passed != total:
        raise TestFailure(f'Sequential tests failed: {passed}/{total}')
