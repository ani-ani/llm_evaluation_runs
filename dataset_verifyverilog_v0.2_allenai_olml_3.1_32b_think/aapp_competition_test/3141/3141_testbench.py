import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import math

# Helper functions for fixed-point conversion
def float_to_q16_16(f):
    return int(f * 65536) & 0xFFFFFFFF

def q16_16_to_float(q):
    if q & 0x80000000:  # Negative number
        return (q - 0x100000000) / 65536.0
    return q / 65536.0

def calc_distance_sq(x1, y1, x2, y2):
    dx = x2 - x1
    dy = y2 - y1
    return dx*dx + dy*dy

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    for i in range(8):
        dut.flaw_x[i].value = 0
        dut.flaw_y[i].value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def run_test_case(dut, flaws):
    """Run a single test case with given flaw coordinates"""
    N = len(flaws)
    
    # Load inputs
    for i in range(8):
        if i < N:
            dut.flaw_x[i].value = float_to_q16_16(flaws[i][0])
            dut.flaw_y[i].value = float_to_q16_16(flaws[i][1])
        else:
            # Use first point for remaining slots to avoid undefined behavior
            dut.flaw_x[i].value = float_to_q16_16(flaws[0][0])
            dut.flaw_y[i].value = float_to_q16_16(flaws[0][1])
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 100
    for _ in range(timeout):
        if dut.done.value == 1:
            break
        await RisingEdge(dut.clk)
    else:
        raise TimeoutError("Module did not complete in time")
    
    # Get result
    result_q = int(dut.diameter.value)
    result = q16_16_to_float(result_q)
    return result

@cocotb.test()
async def test_drill_diameter(dut):
    """Test the drill diameter calculator with multiple test cases"""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (flaw_x, flaw_y, expected_diameter)
    test_cases = [
        # Test case 1: 3 flaws
        [(1.0, 0.0), (-1.0, 0.0), (0.0, 1.0)],
        # Test case 2: 5 flaws  
        [(1.4, 1.0), (-0.4, -1.0), (-0.1, -0.25), (-1.2, 0.0), (0.2, 0.5)],
        # Test case 3: 8 flaws
        [(435.249, -494.71), (455.823, -507.454), (423.394, -520.682),
         (446.507, -501.953), (434.266, -503.664), (445.059, -549.71),
         (449.65, -506.637), (456.05, -499.715)],
        # Test case 4: 2 points
        [(0.0, 0.0), (1.0, 0.0)],
        # Test case 5: Square pattern
        [(0.0, 0.0), (1.0, 0.0), (0.0, 1.0), (1.0, 1.0)],
    ]
    
    passed = 0
    total = len(test_cases)
    
    for idx, flaws in enumerate(test_cases):
        print(f"
Test case {idx + 1}: {len(flaws)} flaws")
        
        result = await run_test_case(dut, flaws)
        
        # Calculate expected diameter using Python for verification
        if len(flaws) == 1:
            expected = 0.0
        else:
            # Brute force minimum enclosing circle for verification
            best_diam = float('inf')
            
            # Check all pairs as diameter
            for i in range(len(flaws)):
                for j in range(i + 1, len(flaws)):
                    cx = (flaws[i][0] + flaws[j][0]) / 2
                    cy = (flaws[i][1] + flaws[j][1]) / 2
                    r = math.sqrt((flaws[i][0] - cx)**2 + (flaws[i][1] - cy)**2)
                    valid = True
                    for k in range(len(flaws)):
                        dist = math.sqrt((flaws[k][0] - cx)**2 + (flaws[k][1] - cy)**2)
                        if dist > r + 1e-6:
                            valid = False
                            break
                    if valid:
                        best_diam = min(best_diam, 2 * r)
            
            # Check all triplets as circumcircle
            for i in range(len(flaws)):
                for j in range(i + 1, len(flaws)):
                    for k in range(j + 1, len(flaws)):
                        x1, y1 = flaws[i]
                        x2, y2 = flaws[j]
                        x3, y3 = flaws[k]
                        
                        # Check if points are collinear
                        if abs((x2-x1)*(y3-y1) - (y2-y1)*(x3-x1)) < 1e-9:
                            continue
                        
                        # Calculate circumcenter
                        d = 2 * (x1*(y2-y3) + x2*(y3-y1) + x3*(y1-y2))
                        if abs(d) < 1e-9:
                            continue
                        
                        ux = ((x1**2 + y1**2)*(y2-y3) + (x2**2 + y2**2)*(y3-y1) + (x3**2 + y3**2)*(y1-y2)) / d
                        uy = ((x1**2 + y1**2)*(x3-x2) + (x2**2 + y2**2)*(x1-x3) + (x3**2 + y3**2)*(x2-x1)) / d
                        
                        r = math.sqrt((x1 - ux)**2 + (y1 - uy)**2)
                        valid = True
                        for l in range(len(flaws)):
                            dist = math.sqrt((flaws[l][0] - ux)**2 + (flaws[l][1] - uy)**2)
                            if dist > r + 1e-6:
                                valid = False
                                break
                        if valid:
                            best_diam = min(best_diam, 2 * r)
            
            expected = best_diam
        
        print(f"  Result: {result:.6f}, Expected: {expected:.6f}")
        
        # Allow 1% error for approximation
        if expected < 0.01:
            # Very small expected value, use absolute error
            if abs(result - expected) < 0.05:
                passed += 1
                print("  PASSED")
            else:
                print("  FAILED")
        else:
            # Use relative error
            rel_err = abs(result - expected) / expected
            if rel_err < 0.02:
                passed += 1
                print("  PASSED")
            else:
                print("  FAILED")
    
    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"
