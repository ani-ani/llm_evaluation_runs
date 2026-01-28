import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

def to_signed(val, bits):
    """Convert unsigned integer to signed (two's complement)."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    """Convert signed integer to unsigned for Verilog assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

# ============================================================================
# PYTHON REFERENCE IMPLEMENTATION
# ============================================================================

def solve_fence(K, N, poles):
    """Reference implementation for algorithm."""
    if K == 0 or N == 0:
        return 0
    
    # Step 1: Find maximum L
    max_p = max(poles)
    L = max_p
    while L > 0:
        total = sum(p // L for p in poles)
        if total >= N:
            break
        L -= 1
    
    # Step 2: Build D array
    D = []
    for p in poles:
        if p % L == 0:
            D.append(p // L)
    
    # Step 3: Sort D
    D.sort()
    
    # Step 4: Find t
    prefix = 0
    t = 0
    for k in D:
        if prefix + k <= N:
            prefix += k
            t += 1
        else:
            break
    
    # Step 5: Result
    return N - t

# ============================================================================
# COCOTB TESTBENCH
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_fence_posts(dut):
    """Test fence posts module with scaled constraints."""
    
    # Configuration matching HDL
    CLK_PERIOD_NS = 10
    DATA_WIDTH = 8
    ARRAY_SIZE = 8
    
    # Start clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset sequence
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        for _ in range(2):
            if has_signal(dut, 'clk'):
                await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
    
    # Test cases: (K, N, poles, expected_cuts, description)
    # Scaled to K≤8, N≤16, p_i≤255
    test_cases = [
        (1, 2, [3], 1, "Single pole, need 2 posts"),
        (2, 5, [4, 2], 4, "Two poles, need 5 posts"),
        (3, 4, [5, 2, 2], 2, "Three poles, need 4 posts"),
        (2, 4, [4, 4], 2, "Two equal poles, need 4 posts"),
        (1, 3, [9], 2, "Single pole, need 3 posts"),
        (3, 3, [3, 3, 3], 2, "Three equal poles, need 3 posts"),
        (4, 8, [10, 10, 10, 10], 4, "Four poles, need 8 posts"),
        (2, 6, [7, 5], 4, "Two poles, need 6 posts"),
    ]
    
    passed = 0
    failed = 0
    
    for K, N, poles, expected_cuts, description in test_cases:
        cocotb.log.info(f"\nTest {passed+failed+1}: {description}")
        cocotb.log.info(f"  Input: K={K}, N={N}, poles={poles}")
        
        # Scale inputs to HDL width constraints
        K_scaled = clamp_to_width(K, 4)
        N_scaled = clamp_to_width(N, 4)
        poles_scaled = [clamp_to_width(p, DATA_WIDTH) for p in poles]
        
        # Verify reference implementation matches expected
        ref_result = solve_fence(K, N, poles)
        if ref_result != expected_cuts:
            cocotb.log.error(f"  Reference error: expected {expected_cuts}, got {ref_result}")
            failed += 1
            continue
        
        # Write K and N
        if has_signal(dut, 'K'):
            dut.K.value = K_scaled
        if has_signal(dut, 'N'):
            dut.N.value = N_scaled
        
        # Write pole array - handle both indexed and packed formats
        for i in range(ARRAY_SIZE):
            val = poles_scaled[i] if i < len(poles_scaled) else 0
            
            # Try indexed array first (p[i])
            if has_signal(dut, 'p'):
                try:
                    dut.p[i].value = val
                    continue
                except (AttributeError, TypeError):
                    pass
            
            # Try individual ports (p_0, p_1, ...)
            port_name = f'p_{i}'
            if has_signal(dut, port_name):
                getattr(dut, port_name).value = val
            else:
                raise TestFailure(f"Cannot find array port: p[{i}] or {port_name}")
        
        # Start computation
        if has_signal(dut, 'start'):
            dut.start.value = 1
            if has_signal(dut, 'clk'):
                await RisingEdge(dut.clk)
            dut.start.value = 0
        else:
            # Combinational - wait for propagation
            await Timer(100, units='ns')
        
        # Wait for done with timeout
        if has_signal(dut, 'done'):
            timed_out = True
            for cycle in range(256):  # Should complete within 256 cycles
                if has_signal(dut, 'clk'):
                    await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    timed_out = False
                    break
            
            if timed_out:
                cocotb.log.error(f"  TIMEOUT: done not asserted")
                failed += 1
                continue
        else:
            # Combinational module
            await Timer(200, units='ns')
        
        # Read result
        if not is_value_defined(dut.cuts.value):
            cocotb.log.error(f"  FAIL: Result is undefined (X/Z)")
            failed += 1
            continue
        
        result = int(dut.cuts.value)
        
        # Verify result
        if result != expected_cuts:
            cocotb.log.error(f"  FAIL: Expected {expected_cuts}, got {result}")
            failed += 1
        else:
            cocotb.log.info(f"  PASS: cuts = {result}")
            passed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"RESULTS: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
    
    cocotb.log.info("All tests completed successfully!")
