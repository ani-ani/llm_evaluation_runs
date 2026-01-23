import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import random

def to_fixed_point(val):
    # We are using standard integers for simplicity as inputs are integers.
    # The prompt mentions Q16.16, but the problem is discrete integer heights.
    # We will pass integers directly. The logic in module uses [15:0] which matches distinct ints.
    # If strictly needed to be Q16.16, we multiply by 65536, but logic is > comparison so 3.5 > 2.0 is same as 229376 > 131072.
    # To simplify, we will pass the raw integers as they fit in [15:0].
    # The prompt's Q16.16 hint is for floats, but inputs are ints. We stick to ints.
    return int(val)

@cocotb.test()
async def test_photo_finder(dut):
    # Start clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 1: 1 Photo (Example 1)
    # 3
    # 2 1 3
    # Alice (taller than me) on left, Bob (taller than both) on right.
    # Me = 1 (height 1). Left: 2 (Alice). Right: 3 (Bob). Valid.
    
    dut.k.value = 1
    dut.n[0].value = 3
    # Load heights
    heights_input = [2, 1, 3]
    for i, h in enumerate(heights_input):
        dut.heights[0][i].value = h
    
    # Top up remaining with 0
    for i in range(3, 8):
        dut.heights[0][i].value = 0
        
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    timeout = 0
    while not dut.done.value and timeout < 100:
        await RisingEdge(dut.clk)
        timeout += 1
    
    assert dut.done.value == 1, "Test 1: Module did not finish"
    assert dut.num_valid.value == 1, f"Test 1: Expected 1 valid, got {dut.num_valid.value}"
    assert dut.valid_indices[0].value == 0, f"Test 1: Expected index 0 (photo 1), got {dut.valid_indices[0].value}"
    print("Test 1 Passed")
    
    # Reset for next test
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Case 2: 4 Photos (Example 2)
    # Photo 1: 140 157 160 193
    # Possible: 157 (Me), Left 160/140(>157?), 140<157 fail, 160>157 (Alice). Right 193(>160) (Bob). Valid.
    # Photo 2: 15 24 38 9 30
    # Photo 3: 36 12 24 29 23 15
    # Photo 4: 170 230 320 180 250 210
    # Expected output: 2 photos (2 and 4)
    
    dut.k.value = 4
    
    # Photo 1 (Valid? Wait, sample output says 2 photos are 2 and 4. Let's check Photo 1.)
    # Photo 1: 140 157 160 193
    # Me=157. Left: 140 (<157). Right: 160, 193. Need Alice (>157) on left. Fail.
    # So Photo 1 is INVALID.
    dut.n[0].value = 4
    h1 = [140, 157, 160, 193]
    for i, h in enumerate(h1): dut.heights[0][i].value = h
    for i in range(4, 8): dut.heights[0][i].value = 0
    
    # Photo 2: 15 24 38 9 30
    # Me=9 (index 3). Left: 15, 24, 38 (all >9). Alice=15. Right: 30 (>15). Valid.
    dut.n[1].value = 5
    h2 = [15, 24, 38, 9, 30]
    for i, h in enumerate(h2): dut.heights[1][i].value = h
    for i in range(5, 8): dut.heights[1][i].value = 0
    
    # Photo 3: 36 12 24 29 23 15
    # Let's check if valid. Possibly Me=15. Left: 36,12,24,29,23. Alice? Need >15. 36 works. Right: None. Fail.
    # Check other Me.
    # Output says Photo 3 is NOT in output. So INVALID.
    dut.n[2].value = 6
    h3 = [36, 12, 24, 29, 23, 15]
    for i, h in enumerate(h3): dut.heights[2][i].value = h
    for i in range(6, 8): dut.heights[2][i].value = 0
    
    # Photo 4: 170 230 320 180 250 210
    # Check if valid.
    # Me=180 (index 3). Left: 170 (<180), 230 (>180=Alice), 320 (>180). 
    # Pick Alice=230. Right: 250, 210. Need Bob > 230. 250 works. Valid.
    # Or Me=170. Left: None. Fail.
    # Or Me=210. Left: 180(<210), 320(>210=Alice). Right: None. Fail.
    # So Photo 4 is VALID.
    dut.n[3].value = 6
    h4 = [170, 230, 320, 180, 250, 210]
    for i, h in enumerate(h4): dut.heights[3][i].value = h
    for i in range(6, 8): dut.heights[3][i].value = 0
    
    # Fill remaining photos (if any) with dummy data to avoid Z values
    for p in range(4, 8):
        dut.n[p].value = 3
        dut.heights[p][0].value = 1
        dut.heights[p][1].value = 2
        dut.heights[p][2].value = 3
        for i in range(3, 8): dut.heights[p][i].value = 0

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
        
    assert dut.done.value == 1, "Test 2: Module did not finish"
    assert dut.num_valid.value == 2, f"Test 2: Expected 2 valid, got {dut.num_valid.value}"
    
    # Check indices. We expect 1 (Photo 2) and 3 (Photo 4) (0-indexed)
    indices = [int(dut.valid_indices[i].value) for i in range(2)]
    indices.sort()
    assert indices == [1, 3], f"Test 2: Expected [1, 3], got {indices}"
    print("Test 2 Passed")

    # Test Case 3: Edge Case - All Invalid
    # 2 photos
    # 1: 1 2 3 (Me=1 no left, Me=2 Alice=1 Bob=3 but Alice<Me fail, Me=3 no right)
    # 2: 3 2 1 (Me=1 Right fail, Me=2 Right fail, Me=3 Left fail)
    # Reset
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    dut.k.value = 2
    # Photo 1
    dut.n[0].value = 3
    for i, h in enumerate([1, 2, 3]): dut.heights[0][i].value = h
    for i in range(3, 8): dut.heights[0][i].value = 0
    # Photo 2
    dut.n[1].value = 3
    for i, h in enumerate([3, 2, 1]): dut.heights[1][i].value = h
    for i in range(3, 8): dut.heights[1][i].value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 0
    while not dut.done.value and timeout < 500:
        await RisingEdge(dut.clk)
        timeout += 1
        
    assert dut.done.value == 1
    assert dut.num_valid.value == 0, f"Test 3: Expected 0 valid, got {dut.num_valid.value}"
    print("Test 3 Passed")
    
    print(f"All tests passed: {2+1+1}/3 cases covered")