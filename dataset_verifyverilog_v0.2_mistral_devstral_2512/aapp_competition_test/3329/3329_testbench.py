import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

def rotate_circle(circle, n, shift):
    """Rotate circle by shift positions"""
    result = 0
    for i in range(n):
        # Get bit at position (i+shift)%n
        bit = (circle >> ((i + shift) % n)) & 1
        result |= (bit << i)
    return result

def apply_transform(circle, n):
    """Apply one transformation step"""
    result = 0
    for i in range(n):
        bit_i = (circle >> i) & 1
        bit_next = (circle >> ((i + 1) % n)) & 1
        new_bit = 1 if bit_i == bit_next else 0
        result |= (new_bit << i)
    return result

def apply_k_transformations(circle, n, k):
    """Apply K transformations"""
    for _ in range(k):
        circle = apply_transform(circle, n)
    return circle

def is_equivalent(target, candidate, n):
    """Check if candidate is rotation-equivalent to target"""
    for shift in range(n):
        rotated = rotate_circle(candidate, n, shift)
        if rotated == target:
            return True
    return False

def count_matching_starting(n, k, target):
    """Count distinct starting circles (reference implementation)"""
    count = 0
    total = 1 << n
    for start in range(total):
        # Normalize start by finding canonical rotation
        canonical = start
        for shift in range(1, n):
            rotated = rotate_circle(start, n, shift)
            if rotated < canonical:
                canonical = rotated
        
        # Only count if this is the canonical representation
        if start != canonical:
            continue
            
        result = apply_k_transformations(start, n, k)
        if is_equivalent(target, result, n):
            count += 1
    return count

@cocotb.test()
async def test_pebble_transform_basic(dut):
    """Test basic functionality with N=3, K=1, target=BBW (010)"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.N.value = 0
    dut.K.value = 0
    dut.target_circle.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case: N=3, K=1, target=BBW
    # BBW = positions 0=B, 1=B, 2=W = 0b011 = 3
    dut.N.value = 3
    dut.K.value = 1
    dut.target_circle.value = 3  # 0b011
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for completion (check done signal)
    timeout = 0
    while not dut.done.value and timeout < 10000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 10000:
        raise TestFailure("Timeout waiting for completion")
    
    # Expected: 2 (starting circles BBW and WWW both give BBW after 1 transform)
    expected = count_matching_starting(3, 1, 3)
    
    if dut.result.value != expected:
        raise TestFailure(f"Result mismatch: got {dut.result.value}, expected {expected}")
    
    print(f"Test 1: N=3, K=1, target=BBW -> Result={int(dut.result.value)} (expected {expected})")

@cocotb.test()
async def test_pebble_transform_case2(dut):
    """Test with N=6, K=2, target=WBWWBW"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # WBWWBW = W B W W B W = 0 1 0 0 1 0 = 0b010010 = 0x12
    dut.N.value = 6
    dut.K.value = 2
    dut.target_circle.value = 0x12
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 20000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 20000:
        raise TestFailure("Timeout waiting for completion")
    
    expected = count_matching_starting(6, 2, 0x12)
    
    if dut.result.value != expected:
        raise TestFailure(f"Result mismatch: got {dut.result.value}, expected {expected}")
    
    print(f"Test 2: N=6, K=2, target=WBWWBW -> Result={int(dut.result.value)} (expected {expected})")

@cocotb.test()
async def test_pebble_transform_all_black(dut):
    """Test edge case: all black circle"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # All black = 0xFF for N=8, but use N=4
    dut.N.value = 4
    dut.K.value = 2
    dut.target_circle.value = 0xF  # All black
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 5000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 5000:
        raise TestFailure("Timeout")
    
    expected = count_matching_starting(4, 2, 0xF)
    
    if dut.result.value != expected:
        raise TestFailure(f"Result mismatch: got {dut.result.value}, expected {expected}")
    
    print(f"Test 3: N=4, K=2, target=BBBB -> Result={int(dut.result.value)} (expected {expected})")

@cocotb.test()
async def test_pebble_transform_alternating(dut):
    """Test with alternating pattern"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # BWBW = 0b1010 for N=4
    dut.N.value = 4
    dut.K.value = 1
    dut.target_circle.value = 0xA  # 1010
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 5000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 5000:
        raise TestFailure("Timeout")
    
    expected = count_matching_starting(4, 1, 0xA)
    
    if dut.result.value != expected:
        raise TestFailure(f"Result mismatch: got {dut.result.value}, expected {expected}")
    
    print(f"Test 4: N=4, K=1, target=BWBW -> Result={int(dut.result.value)} (expected {expected})")

@cocotb.test()
async def test_pebble_transform_single(dut):
    """Test minimal case: N=3, K=1, target=WWB"""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # WWB = 0 0 1 = 0b001 = 1
    dut.N.value = 3
    dut.K.value = 1
    dut.target_circle.value = 1
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 10000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 10000:
        raise TestFailure("Timeout")
    
    expected = count_matching_starting(3, 1, 1)
    
    if dut.result.value != expected:
        raise TestFailure(f"Result mismatch: got {dut.result.value}, expected {expected}")
    
    print(f"Test 5: N=3, K=1, target=WWB -> Result={int(dut.result.value)} (expected {expected})")
    print(f"
All 5 tests completed successfully!")