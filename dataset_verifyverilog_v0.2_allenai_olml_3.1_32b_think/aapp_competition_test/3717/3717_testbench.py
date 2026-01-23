import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import random

def intersect_rects(rects):
    """Compute intersection of list of rectangles"""
    if not rects:
        return None
    max_x1 = max(r[0] for r in rects)
    max_y1 = max(r[1] for r in rects)
    min_x2 = min(r[2] for r in rects)
    min_y2 = min(r[3] for r in rects)
    if max_x1 <= min_x2 and max_y1 <= min_y2:
        return (max_x1, max_y1, min_x2, min_y2)
    return None

def solve_exclusion(rects, n):
    """Find point in at least n-1 rectangles by trying each exclusion"""
    for i in range(n):
        # Try excluding rectangle i
        others = [rects[j] for j in range(n) if j != i]
        inter = intersect_rects(others)
        if inter is not None:
            return (inter[0], inter[1])
    return (0, 0)

@cocotb.test()
async def test_find_common_point(dut):
    """Test find_common_point module"""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.x1_in.value = 0
    dut.y1_in.value = 0
    dut.x2_in.value = 0
    dut.y2_in.value = 0
    dut.n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        # (rects, n, description)
        ([(0, 0, 1, 1), (1, 1, 2, 2), (3, 0, 4, 1)], 3, "Sample 1"),
        ([(0, 0, 1, 1), (0, 1, 1, 2), (1, 0, 2, 1)], 3, "Sample 2"),
        ([(0, 0, 5, 5), (0, 0, 4, 4), (1, 1, 4, 4), (1, 1, 4, 4)], 4, "Sample 3"),
        ([(0, 0, 10, 8), (1, 2, 6, 7), (2, 3, 5, 6), (3, 4, 4, 5), (8, 1, 9, 2)], 5, "Sample 4"),
        ([(1, 1, 2, 2), (3, 3, 4, 4), (4, 4, 5, 5)], 3, "No overlap"),
        ([(0, 0, 1, 1), (10, 10, 11, 11), (11, 11, 12, 12)], 3, "Sparse"),
        ([(1, 1, 2, 2), (1, 1, 2, 2), (1, 100, 2, 101)], 3, "Two same, one different"),
        ([(0, 0, 1, 1), (2, 2, 3, 3), (2, 2, 3, 3)], 3, "Two same, one isolated"),
        ([(1, 1, 2, 2), (2, 2, 3, 3), (0, 0, 1, 1), (1, 0, 2, 1)], 4, "Four rects, complex"),
        ([(0, 0, 2, 2), (0, 2, 2, 4), (0, 6, 2, 8)], 3, "Vertical stack"),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for rects, n, desc in test_cases:
        print(f"
Test: {desc}")
        print(f"Rectangles: {rects}")
        
        # Compute expected
        expected_x, expected_y = solve_exclusion(rects, n)
        print(f"Expected: ({expected_x}, {expected_y})")
        
        # Reset for new test
        dut.rst_n.value = 0
        await Timer(10, units='ns')
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        dut.start.value = 0
        await RisingEdge(dut.clk)
        
        # Load rectangles
        dut.n.value = n
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed rectangles one by one
        for rect in rects:
            dut.x1_in.value = rect[0] & 0xFF
            dut.y1_in.value = rect[1] & 0xFF
            dut.x2_in.value = rect[2] & 0xFF
            dut.y2_in.value = rect[3] & 0xFF
            await RisingEdge(dut.clk)
        
        # Wait for computation
        max_cycles = 100
        for _ in range(max_cycles):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        else:
            raise TestFailure(f"Timeout for {desc}")
        
        # Check result
        if dut.valid.value != 1:
            print(f"Result invalid for {desc}")
            continue
            
        result_x = dut.result_x.value
        result_y = dut.result_y.value
        
        # Convert signed if needed (handle 8-bit signed)
        if result_x >= 128:
            result_x = result_x - 256
        if result_y >= 128:
            result_y = result_y - 256
        
        print(f"Got: ({result_x}, {result_y})")
        
        # Check if result is valid by verifying it's in at least n-1 rectangles
        valid_count = 0
        for rect in rects:
            if rect[0] <= result_x <= rect[2] and rect[1] <= result_y <= rect[3]:
                valid_count += 1
        
        if valid_count >= n - 1:
            print(f"✓ PASS: Point ({result_x}, {result_y}) is in {valid_count} rectangles")
            passed += 1
        else:
            print(f"✗ FAIL: Point ({result_x}, {result_y}) only in {valid_count} rectangles")
    
    print(f"
{'='*50}")
    print(f"SUMMARY: {passed}/{total} tests passed")
    print(f"{'='*50}")
    
    if passed < total:
        raise TestFailure(f"Only {passed}/{total} tests passed")
