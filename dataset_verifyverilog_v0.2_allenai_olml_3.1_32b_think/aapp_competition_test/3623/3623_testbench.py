import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import math

@cocotb.test()
async def test_courtyard_coverage(dut):
    """Test the courtyard coverage calculator with multiple test cases"""
    
    # Create and start clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset the DUT
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.angle_br.value = 0
    dut.angle_tr.value = 0
    dut.angle_tl.value = 0
    dut.angle_bl.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper function to convert degrees to Q16.16
    def deg_to_q16_16(deg):
        return int(deg * 65536)
    
    # Helper function to compute expected coverage (simplified discrete version)
    def compute_expected_coverage(a, b, c, d):
        """Compute coverage using 8x8 grid sampling"""
        covered = 0
        for i in range(8):
            for j in range(8):
                x = i / 8.0 + 0.5/8.0  # center of cell
                y = j / 8.0 + 0.5/8.0
                
                # Check each sprinkler
                is_covered = False
                
                # Bottom-right sprinkler at (1,0)
                if not is_covered and a > 0:
                    dx = x - 1
                    dy = y - 0
                    if dx <= 0 and dy >= 0:
                        angle = math.degrees(math.atan2(dy, -dx))
                        if angle <= a:
                            is_covered = True
                
                # Top-right sprinkler at (1,1)
                if not is_covered and b > 0:
                    dx = x - 1
                    dy = y - 1
                    if dx <= 0 and dy <= 0:
                        angle = math.degrees(math.atan2(-dx, -dy))
                        if angle <= b:
                            is_covered = True
                
                # Top-left sprinkler at (0,1)
                if not is_covered and c > 0:
                    dx = x - 0
                    dy = y - 1
                    if dx >= 0 and dy <= 0:
                        angle = math.degrees(math.atan2(-dy, dx))
                        if angle <= c:
                            is_covered = True
                
                # Bottom-left sprinkler at (0,0)
                if not is_covered and d > 0:
                    dx = x - 0
                    dy = y - 0
                    if dx >= 0 and dy >= 0:
                        angle = math.degrees(math.atan2(dx, dy))
                        if angle <= d:
                            is_covered = True
                
                if is_covered:
                    covered += 1
        
        return covered / 64.0
    
    # Test cases
    test_cases = [
        {"a": 45, "b": 45, "c": 0, "d": 0},
        {"a": 30, "b": 30, "c": 10, "d": 45},
        {"a": 90, "b": 90, "c": 90, "d": 90},
        {"a": 0, "b": 0, "c": 0, "d": 0},
        {"a": 45, "b": 0, "c": 0, "d": 0},
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, test in enumerate(test_cases):
        a, b, c, d = test["a"], test["b"], test["c"], test["d"]
        
        # Set inputs
        dut.angle_br.value = deg_to_q16_16(a)
        dut.angle_tr.value = deg_to_q16_16(b)
        dut.angle_tl.value = deg_to_q16_16(c)
        dut.angle_bl.value = deg_to_q16_16(d)
        
        # Start computation
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (max 80 cycles)
        timeout = 0
        while not dut.done.value and timeout < 100:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 100:
            print(f"Test {i+1}: TIMEOUT - done signal not asserted")
            continue
        
        # Read result
        result_q16_16 = int(dut.proportion.value)
        result = result_q16_16 / 65536.0
        
        # Expected result
        expected = compute_expected_coverage(a, b, c, d)
        
        # Check within tolerance
        error = abs(result - expected)
        tolerance = 1e-4  # More lenient due to discrete sampling
        
        if error <= tolerance:
            passed += 1
            print(f"Test {i+1}: PASS (angles={a},{b},{c},{d}, result={result:.6f}, expected={expected:.6f}, error={error:.8f})")
        else:
            print(f"Test {i+1}: FAIL (angles={a},{b},{c},{d}, result={result:.6f}, expected={expected:.6f}, error={error:.8f})")
        
        await RisingEdge(dut.clk)
    
    print(f"
Summary: {passed}/{total} tests passed")
    assert passed == total, f"Only {passed}/{total} tests passed"