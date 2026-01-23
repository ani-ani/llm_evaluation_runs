import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure
import math

@cocotb.test()
async def test_max_hits(dut):
    """Test max_hits module with various circle configurations"""
    
    # Clock setup
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.valid_mask.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Helper: Convert float to Q16.16
    def to_q16_16(x):
        return int(x * 65536) & 0xFFFFFFFF
    
    # Helper: Expected result for single circle overlap
    def compute_expected(circles):
        # Compute angular intervals and find max overlap
        intervals = []
        for x, y, r in circles:
            # Skip origin (0,0)
            if x == 0 and y == 0:
                continue
            # Compute distances
            dist_sq = x*x + y*y
            dist = math.sqrt(dist_sq)
            # If circle contains origin, skip (guaranteed not to)
            if dist <= r:
                continue
            # Tangent angle offset
            phi = math.atan2(y, x)
            alpha = math.asin(r / dist)
            start = phi - alpha
            end = phi + alpha
            # Normalize to [0, 2π)
            while start < 0:
                start += 2*math.pi
                end += 2*math.pi
            while start >= 2*math.pi:
                start -= 2*math.pi
                end -= 2*math.pi
            if end >= 2*math.pi:
                # Split interval
                intervals.append((start, 2*math.pi))
                intervals.append((0, end - 2*math.pi))
            else:
                intervals.append((start, end))
        
        if not intervals:
            return 0
        
        # Create events
        events = []
        for start, end in intervals:
            events.append((start, 1))
            events.append((end, -1))
        
        # Sort by angle, with -1 (exit) before +1 (enter) at same angle
        events.sort(key=lambda x: (x[0], x[1]))
        
        max_count = 0
        count = 0
        for angle, delta in events:
            count += delta
            if count > max_count:
                max_count = count
        
        return max_count
    
    # Test cases
    test_cases = [
        # Case 1: 5 circles from original problem
        {
            'circles': [(5,0,1), (10,0,1), (0,5,1), (0,-5,1), (-5,0,1)],
            'expected': 2
        },
        # Case 2: 6 circles
        {
            'circles': [(2,2,2), (6,2,1), (10,2,1), (2,6,1), (6,6,1), (2,10,1)],
            'expected': 3
        },
        # Case 3: Single circle
        {
            'circles': [(10,0,1)],
            'expected': 1
        },
        # Case 4: Two overlapping circles
        {
            'circles': [(5,0,3), (5,0,2)],
            'expected': 2
        },
        # Case 5: Four circles at 45 degrees
        {
            'circles': [(10,10,2), (10,-10,2), (-10,10,2), (-10,-10,2)],
            'expected': 2
        },
        # Case 6: Three colinear circles
        {
            'circles': [(5,0,1), (10,0,1), (15,0,1)],
            'expected': 3
        }
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, test in enumerate(test_cases):
        dut._log.info(f"Test case {i+1}: {len(test['circles'])} circles")
        
        # Load inputs
        dut.valid_mask.value = (1 << len(test['circles'])) - 1
        for j, (x, y, r) in enumerate(test['circles']):
            dut.circle_x[j].value = to_q16_16(x)
            dut.circle_y[j].value = to_q16_16(y)
            dut.circle_r[j].value = to_q16_16(r)
        
        # Fill remaining with zeros
        for j in range(len(test['circles']), 8):
            dut.circle_x[j].value = 0
            dut.circle_y[j].value = 0
            dut.circle_r[j].value = 0
        
        # Wait for computation (32 cycles + some margin)
        for _ in range(40):
            await RisingEdge(dut.clk)
        
        # Read result
        result = int(dut.max_hits.value)
        expected = test['expected']
        
        dut._log.info(f"  Result: {result}, Expected: {expected}")
        
        if result == expected:
            passed += 1
        else:
            raise TestFailure(f"Test {i+1} failed: got {result}, expected {expected}")
    
    dut._log.info(f"
=== Summary: {passed}/{total} tests passed ===")
