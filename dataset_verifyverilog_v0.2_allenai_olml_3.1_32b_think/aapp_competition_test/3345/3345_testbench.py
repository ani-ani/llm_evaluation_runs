import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
from cocotb.result import TestFailure
import math

@cocotb.test()
async def test_dog_walk_min_distance(dut):
    """Test dog walk minimum distance calculation with multiple test cases"""
    
    # Helper function to convert decimal to Q8.8 fixed-point
    def to_q88(value):
        return int(value * 256) & 0xFFFF
    
    # Helper function to convert Q8.8 to decimal
    def from_q88(value):
        if value & 0x8000:  # Negative
            return -((~value + 1) & 0xFFFF) / 256.0
        return value / 256.0
    
    # Helper to compute Euclidean distance
    def euclidean_distance(x1, y1, x2, y2):
        return math.sqrt((x1 - x2)**2 + (y1 - y2)**2)
    
    # Test case 1: Shadow goes from (0,0) to (10,0), Lydia from (30,0) to (15,0)
    # Expected: minimum distance = 10 at time when Shadow at (10,0), Lydia at (15,0)
    # Shadow: 2 points, path: (0,0) -> (10,0), length=10
    # Lydia: 2 points, path: (30,0) -> (15,0), length=15
    # Shadow finishes first (10 units vs 15 units)
    # At t=10: Shadow at (10,0), Lydia at (30,0) - (15/15)*(15,0) = (15,0)
    # Distance = 5... wait, minimum occurs earlier
    # Actually: Shadow moves 1 unit/s, Lydia 1 unit/s (normalized)
    # At time t (0<=t<=10): Shadow at (t,0), Lydia at (30-1.5t,0)
    # Distance = |30-1.5t - t| = |30-2.5t|, min at t=10 gives 5... but output says 10
    # Wait, let me recalculate with proper speed scaling
    # Both dogs walk at same speed, meaning they cover distance at same rate
    # Shadow distance = t, Lydia distance = t
    # Shadow position: (t, 0) for t in [0,10]
    # Lydia position: starts at (30,0), moves toward (15,0), distance 15
    # At time t <= 10: Lydia covered t units, position = 30 - (t/15)*15 = 30 - t
    # Distance = |(30-t) - t| = |30-2t|, minimum at t=10 is 10 (30-20=10)
    # Yes! Output 10 is correct
    
    test_cases = [
        {
            'name': 'Test 1: Simple horizontal walks',
            'shadow': [(0,0), (10,0)],
            'lydia': [(30,0), (15,0)],
            'expected': 10.0
        },
        {
            'name': 'Test 2: Complex paths with diagonal',
            'shadow': [(10,0), (10,8), (2,8), (2,0), (10,0)],
            'lydia': [(0,8), (4,8), (4,12), (0,12), (0,8), (4,8), (4,12), (0,12), (0,8)],
            'expected': math.sqrt(2)  # ~1.414213562373
        },
        {
            'name': 'Test 3: Same path, offset start',
            'shadow': [(0,0), (5,5)],
            'lydia': [(1,1), (6,6)],
            'expected': math.sqrt(2)  # Minimum distance = sqrt(2)
        },
        {
            'name': 'Test 4: Perpendicular paths',
            'shadow': [(0,0), (10,0)],
            'lydia': [(5,5), (5,-5)],
            'expected': 5.0  # Lydia passes through (5,0) when Shadow is at (5,0)
        },
        {
            'name': 'Test 5: One stationary',
            'shadow': [(0,0), (0,0)],
            'lydia': [(5,0), (5,10)],
            'expected': 5.0
        }
    ]
    
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(5):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    passed = 0
    total = len(test_cases)
    
    for test in test_cases:
        dut._log.info(f"
{test['name']}")
        
        # Load inputs
        shadow_pts = test['shadow']
        lydia_pts = test['lydia']
        
        dut.shadow_count.value = len(shadow_pts)
        dut.lydia_count.value = len(lydia_pts)
        
        # Initialize all arrays to 0
        for i in range(16):
            dut.shadow_x[i].value = 0
            dut.shadow_y[i].value = 0
            dut.lydia_x[i].value = 0
            dut.lydia_y[i].value = 0
        
        # Set actual values
        for i, (x, y) in enumerate(shadow_pts):
            dut.shadow_x[i].value = to_q88(x)
            dut.shadow_y[i].value = to_q88(y)
        
        for i, (x, y) in enumerate(lydia_pts):
            dut.lydia_x[i].value = to_q88(x)
            dut.lydia_y[i].value = to_q88(y)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        timeout = 2000  # Max cycles
        cycles = 0
        while not dut.done.value and cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
        
        if cycles >= timeout:
            dut._log.error(f"Timeout in {test['name']}")
            continue
        
        # Read result
        result_q88 = int(dut.min_dist_sq.value)
        result_dist = from_q88(result_q88)
        
        # Expected
        expected = test['expected']
        
        # Check with tolerance
        tolerance = 0.1  # 0.1 units absolute error
        absolute_error = abs(result_dist - expected)
        
        dut._log.info(f"Result: {result_dist:.6f}, Expected: {expected:.6f}, Error: {absolute_error:.6f}")
        
        if absolute_error <= tolerance:
            dut._log.info(f"PASS")
            passed += 1
        else:
            dut._log.error(f"FAIL: Error {absolute_error:.6f} exceeds tolerance {tolerance}")
    
    # Summary
    dut._log.info(f"
{'='*50}")
    dut._log.info(f"TEST SUMMARY: {passed}/{total} tests passed")
    dut._log.info(f"{'='*50}")
    
    if passed < total:
        raise TestFailure(f"{total - passed} test(s) failed")
