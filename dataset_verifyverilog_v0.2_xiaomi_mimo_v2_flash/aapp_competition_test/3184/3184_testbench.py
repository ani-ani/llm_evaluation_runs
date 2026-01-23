import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

def calculate_min_cameras(n, cameras):
    """Calculate minimum cameras needed for coverage using brute force"""
    # Generate coverage masks
    masks = []
    for a, b in cameras:
        mask = 0
        if a <= b:
            for wall in range(a, b + 1):
                if 1 <= wall <= n:
                    mask |= 1 << (wall - 1)
        else:
            for wall in range(a, n + 1):
                if 1 <= wall <= n:
                    mask |= 1 << (wall - 1)
            for wall in range(1, b + 1):
                if 1 <= wall <= n:
                    mask |= 1 << (wall - 1)
        masks.append(mask)
    
    full_mask = (1 << n) - 1
    
    # Try all combinations
    k = len(cameras)
    min_needed = None
    
    for size in range(1, k + 1):
        # Generate all combinations of size 'size'
        if try_combination(masks, full_mask, size):
            min_needed = size
            break
    
    return min_needed

def try_combination(masks, full_mask, size):
    """Check if any combination of given size covers all walls"""
    k = len(masks)
    if size > k:
        return False
    
    # Generate all combinations using recursion
    def generate_combinations(start, remaining, current_mask):
        if remaining == 0:
            return current_mask == full_mask
        
        for i in range(start, k):
            new_mask = current_mask | masks[i]
            if generate_combinations(i + 1, remaining - 1, new_mask):
                return True
        return False
    
    return generate_combinations(0, size, 0)

@cocotb.test()
async def test_camera_coverage_basic(dut):
    """Test basic camera coverage scenarios"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    print("
Test 1: Sample Input 1 (100 walls -> scaled to 8 walls, 7 cameras)")
    # Original: n=100, k=7
    # Adapted: n=8, k=7 (scale down proportionally)
    # Original ranges: [1,50], [50,70], [70,90], [90,40], [20,60], [60,80], [80,20]
    # Scaled to n=8: [1,4], [4,5], [5,7], [7,3], [2,4], [4,6], [6,2]
    n = 8
    k = 7
    cameras = [(1, 4), (4, 5), (5, 7), (7, 3), (2, 4), (4, 6), (6, 2)]
    
    # Load inputs
    dut.n.value = n
    dut.k.value = k
    for i in range(k):
        dut.a_i[i].value = cameras[i][0]
        dut.b_i[i].value = cameras[i][1]
    for i in range(k, 8):
        dut.a_i[i].value = 0
        dut.b_i[i].value = 0
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 1000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 1000:
        raise TestFailure("Test 1: Timeout - computation did not complete")
    
    expected = calculate_min_cameras(n, cameras)
    actual = int(dut.result.value)
    impossible = int(dut.impossible.value)
    
    if expected is None:
        if not impossible:
            raise TestFailure(f"Test 1: Expected impossible but got result={actual}")
        print(f"  Result: impossible (correct)")
    else:
        if impossible:
            raise TestFailure(f"Test 1: Expected {expected} but got impossible")
        if actual != expected:
            raise TestFailure(f"Test 1: Expected {expected} but got {actual}")
        print(f"  Result: {actual} cameras (correct)")
    
    await RisingEdge(dut.clk)
    
    # Test 2: Impossible case
    print("
Test 2: Impossible coverage")
    # Original: n=8, cameras [8,3], [5,7]
    # This leaves wall 4 uncovered
    n = 8
    k = 2
    cameras = [(8, 3), (5, 7)]
    
    dut.n.value = n
    dut.k.value = k
    for i in range(k):
        dut.a_i[i].value = cameras[i][0]
        dut.b_i[i].value = cameras[i][1]
    for i in range(k, 8):
        dut.a_i[i].value = 0
        dut.b_i[i].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 1000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 1000:
        raise TestFailure("Test 2: Timeout")
    
    expected = calculate_min_cameras(n, cameras)
    actual = int(dut.result.value)
    impossible = int(dut.impossible.value)
    
    if expected is None:
        if not impossible:
            raise TestFailure(f"Test 2: Expected impossible but got result={actual}")
        print(f"  Result: impossible (correct)")
    else:
        if impossible:
            raise TestFailure(f"Test 2: Expected {expected} but got impossible")
        if actual != expected:
            raise TestFailure(f"Test 2: Expected {expected} but got {actual}")
        print(f"  Result: {actual} cameras (correct)")
    
    await RisingEdge(dut.clk)
    
    # Test 3: Coverable with 2 cameras
    print("
Test 3: Coverable with 2 cameras")
    # Original: n=8, cameras [8,4], [5,7]
    n = 8
    k = 2
    cameras = [(8, 4), (5, 7)]
    
    dut.n.value = n
    dut.k.value = k
    for i in range(k):
        dut.a_i[i].value = cameras[i][0]
        dut.b_i[i].value = cameras[i][1]
    for i in range(k, 8):
        dut.a_i[i].value = 0
        dut.b_i[i].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 1000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 1000:
        raise TestFailure("Test 3: Timeout")
    
    expected = calculate_min_cameras(n, cameras)
    actual = int(dut.result.value)
    impossible = int(dut.impossible.value)
    
    if expected is None:
        if not impossible:
            raise TestFailure(f"Test 3: Expected impossible but got result={actual}")
        print(f"  Result: impossible (correct)")
    else:
        if impossible:
            raise TestFailure(f"Test 3: Expected {expected} but got impossible")
        if actual != expected:
            raise TestFailure(f"Test 3: Expected {expected} but got {actual}")
        print(f"  Result: {actual} cameras (correct)")
    
    await RisingEdge(dut.clk)
    
    # Test 4: Single camera covers all
    print("
Test 4: Single camera covers all")
    n = 5
    k = 1
    cameras = [(1, 5)]
    
    dut.n.value = n
    dut.k.value = k
    dut.a_i[0].value = 1
    dut.b_i[0].value = 5
    for i in range(1, 8):
        dut.a_i[i].value = 0
        dut.b_i[i].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 1000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 1000:
        raise TestFailure("Test 4: Timeout")
    
    expected = calculate_min_cameras(n, cameras)
    actual = int(dut.result.value)
    impossible = int(dut.impossible.value)
    
    if expected is None:
        if not impossible:
            raise TestFailure(f"Test 4: Expected impossible but got result={actual}")
        print(f"  Result: impossible (correct)")
    else:
        if impossible:
            raise TestFailure(f"Test 4: Expected {expected} but got impossible")
        if actual != expected:
            raise TestFailure(f"Test 4: Expected {expected} but got {actual}")
        print(f"  Result: {actual} cameras (correct)")
    
    await RisingEdge(dut.clk)
    
    # Test 5: Wrap-around coverage
    print("
Test 5: Wrap-around coverage")
    n = 6
    k = 2
    cameras = [(5, 2), (2, 4)]
    
    dut.n.value = n
    dut.k.value = k
    for i in range(k):
        dut.a_i[i].value = cameras[i][0]
        dut.b_i[i].value = cameras[i][1]
    for i in range(k, 8):
        dut.a_i[i].value = 0
        dut.b_i[i].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 1000:
        await RisingEdge(dut.clk)
        timeout += 1
    
    if timeout >= 1000:
        raise TestFailure("Test 5: Timeout")
    
    expected = calculate_min_cameras(n, cameras)
    actual = int(dut.result.value)
    impossible = int(dut.impossible.value)
    
    if expected is None:
        if not impossible:
            raise TestFailure(f"Test 5: Expected impossible but got result={actual}")
        print(f"  Result: impossible (correct)")
    else:
        if impossible:
            raise TestFailure(f"Test 5: Expected {expected} but got impossible")
        if actual != expected:
            raise TestFailure(f"Test 5: Expected {expected} but got {actual}")
        print(f"  Result: {actual} cameras (correct)")
    
    await RisingEdge(dut.clk)
    
    print("
" + "="*50)
    print("All tests passed!")
    print("="*50)