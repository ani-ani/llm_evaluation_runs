import cocotb
from cocotb.triggers import Timer
import math

# Helper function to convert float to Q16.16 fixed point
def float_to_q16(x):
    return int(x * 65536) & 0xFFFFFFFF

# Helper function to convert Q16.16 to float
def q16_to_float(x):
    # Handle signed 32-bit
    if x > 0x7FFFFFFF:
        x = x - 0x100000000
    return x / 65536.0

@cocotb.test()
async def test_bottle_collector(dut):
    """Test the bottle collector module with multiple test cases"""
    
    # Test case 1: Simple case from problem
    # Adil at (3,1), Bera at (1,2), Bin at (0,0)
    # 3 bottles: (1,1), (2,1), (2,3)
    ax, ay = 3.0, 1.0
    bx, by = 1.0, 2.0
    tx, ty = 0.0, 0.0
    n = 3
    bottles = [(1.0, 1.0), (2.0, 1.0), (2.0, 3.0)]
    
    dut.ax.value = float_to_q16(ax)
    dut.ay.value = float_to_q16(ay)
    dut.bx.value = float_to_q16(bx)
    dut.by.value = float_to_q16(by)
    dut.tx.value = float_to_q16(tx)
    dut.ty.value = float_to_q16(ty)
    dut.n.value = n
    
    for i in range(8):
        if i < n:
            dut.bottle_x[i].value = float_to_q16(bottles[i][0])
            dut.bottle_y[i].value = float_to_q16(bottles[i][1])
        else:
            dut.bottle_x[i].value = 0
            dut.bottle_y[i].value = 0
    
    await Timer(10, units='ns')
    
    result = q16_to_float(int(dut.min_distance.value))
    expected = 11.084259940083
    
    dut._log.info(f"Test 1: Result={result:.6f}, Expected={expected:.6f}")
    assert abs(result - expected) < 0.01, f"Test 1 failed: {result} != {expected}"
    
    # Test case 2: Single bottle
    # Adil at (0,0), Bera at (1,1), Bin at (2,2), Bottle at (1,2)
    dut.ax.value = float_to_q16(0.0)
    dut.ay.value = float_to_q16(0.0)
    dut.bx.value = float_to_q16(1.0)
    dut.by.value = float_to_q16(1.0)
    dut.tx.value = float_to_q16(2.0)
    dut.ty.value = float_to_q16(2.0)
    dut.n.value = 1
    dut.bottle_x[0].value = float_to_q16(1.0)
    dut.bottle_y[0].value = float_to_q16(2.0)
    dut.bottle_x[1].value = 0
    dut.bottle_y[1].value = 0
    
    await Timer(10, units='ns')
    
    result = q16_to_float(int(dut.min_distance.value))
    # Expected: min(1->2->0 + 1.414, 2->1->0 + 1.414) = min(2.828+1.414, 1.414+1.414) = 2.828
    # But actual formula: min(dist(a,1) + dist(1,t), dist(b,1) + dist(1,t)) + other bottles (none)
    expected = 2.414213562373  # Bera picks: sqrt(2) + sqrt(1) = 1.414 + 1 = 2.414
    
    dut._log.info(f"Test 2: Result={result:.6f}, Expected={expected:.6f}")
    assert abs(result - expected) < 0.01, f"Test 2 failed: {result} != {expected}"
    
    # Test case 3: Two bottles
    # Adil at (0,0), Bera at (10,0), Bin at (0,0)
    # Bottles at (0,1), (10,1)
    dut.ax.value = float_to_q16(0.0)
    dut.ay.value = float_to_q16(0.0)
    dut.bx.value = float_to_q16(10.0)
    dut.by.value = float_to_q16(0.0)
    dut.tx.value = float_to_q16(0.0)
    dut.ty.value = float_to_q16(0.0)
    dut.n.value = 2
    dut.bottle_x[0].value = float_to_q16(0.0)
    dut.bottle_y[0].value = float_to_q16(1.0)
    dut.bottle_x[1].value = float_to_q16(10.0)
    dut.bottle_y[1].value = float_to_q16(1.0)
    
    await Timer(10, units='ns')
    
    result = q16_to_float(int(dut.min_distance.value))
    expected = 4.000000000000  # Adil picks (0,1), Bera picks (10,1)
    
    dut._log.info(f"Test 3: Result={result:.6f}, Expected={expected:.6f}")
    assert abs(result - expected) < 0.01, f"Test 3 failed: {result} != {expected}"
    
    # Test case 4: All bottles same, agents far
    # Adil at (0,0), Bera at (100,100), Bin at (0,0), Bottle at (1,0)
    dut.ax.value = float_to_q16(0.0)
    dut.ay.value = float_to_q16(0.0)
    dut.bx.value = float_to_q16(100.0)
    dut.by.value = float_to_q16(100.0)
    dut.tx.value = float_to_q16(0.0)
    dut.ty.value = float_to_q16(0.0)
    dut.n.value = 1
    dut.bottle_x[0].value = float_to_q16(1.0)
    dut.bottle_y[0].value = float_to_q16(0.0)
    dut.bottle_x[1].value = 0
    dut.bottle_y[1].value = 0
    
    await Timer(10, units='ns')
    
    result = q16_to_float(int(dut.min_distance.value))
    expected = 100.000000000000  # Bera picks, saves 0, base cost = 2*1 = 2, but wait...
    # Actually base cost = 2 * dist(bin, bottle) = 2 * 1 = 2
    # Savings from Adil: 1 - 1 = 0
    # Savings from Bera: 1 - 141.42 = -140.42 (negative savings = penalty)
    # Max savings = 0 (Adil picks)
    # Total = 2 - 0 = 2
    # But expected says 100? Let me recalculate...
    # If Bera picks: dist(Bera, bottle) + dist(bottle, bin) = 141.42 + 1 = 142.42
    # If Adil picks: dist(Adil, bottle) + dist(bottle, bin) = 1 + 1 = 2
    # Wait, problem says total distance by BOTH.
    # If Adil picks, Bera does nothing: total = 2
    # If Bera picks, Adil does nothing: total = 142.42
    # So minimum is 2.
    # But looking at the expected output of 100, perhaps my test case setup is wrong.
    # Let me reconsider the problem logic.
    # Actually, the formula is: Base = 2*sum(dist(bin, bottle)), then subtract max savings.
    # For n=1 bottle: Base = 2*1 = 2. Savings = dist(bin, bottle) - dist(agent, bottle)
    # Adil: 1-1=0. Bera: 1-141.42 = -140.42.
    # Max savings = 0. Result = 2 - 0 = 2.
    # I will change this test case to match the formula.
    
    expected = 2.0
    dut._log.info(f"Test 4: Result={result:.6f}, Expected={expected:.6f}")
    assert abs(result - expected) < 0.01, f"Test 4 failed: {result} != {expected}"
    
    # Test case 5: Zero bottles (edge case)
    dut.n.value = 0
    await Timer(10, units='ns')
    result = q16_to_float(int(dut.min_distance.value))
    expected = 0.0
    dut._log.info(f"Test 5: Result={result:.6f}, Expected={expected:.6f}")
    assert abs(result - expected) < 0.01, f"Test 5 failed: {result} != {expected}"
    
    dut._log.info("All tests passed!")
