import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_house_purchase_counter(dut):
    """Test house purchase counter with scaled 8-bit inputs"""
    
    # Create clock (10ns period)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.L.value = 0
    dut.R.value = 0
    await Timer(25, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: [30, 70] -> 11
    # Valid numbers: 36,37,38,56,57,58,60,61,62,63,65,67,68,70
    # No 4, and lucky==unlucky
    # 36: 3(lucky0),6(lucky1) -> 1 vs 1 -> valid
    # 37: 3(lucky0),7(lucky0) -> 0 vs 2 -> invalid
    # 38: 3(lucky0),8(lucky1) -> 1 vs 1 -> valid
    # 56: 5(lucky0),6(lucky1) -> 1 vs 1 -> valid
    # 57: 5(lucky0),7(lucky0) -> 0 vs 2 -> invalid
    # 58: 5(lucky0),8(lucky1) -> 1 vs 1 -> valid
    # 60: 6(lucky1),0(lucky0) -> 1 vs 1 -> valid
    # 61: 6(lucky1),1(lucky0) -> 1 vs 1 -> valid
    # 62: 6(lucky1),2(lucky0) -> 1 vs 1 -> valid
    # 63: 6(lucky1),3(lucky0) -> 1 vs 1 -> valid
    # 65: 6(lucky1),5(lucky0) -> 1 vs 1 -> valid
    # 67: 6(lucky1),7(lucky0) -> 1 vs 1 -> valid
    # 68: 6(lucky1),8(lucky1) -> 2 vs 0 -> invalid
    # 70: 7(lucky0),0(lucky0) -> 0 vs 2 -> invalid
    # 30: 3(lucky0),0(lucky0) -> 0 vs 2 -> invalid
    # Valid ones: 36,38,56,58,60,61,62,63,65,67 = 10? Wait let's recount
    # Also 68 is invalid, but 70... 68 is 2 lucky, 0 unlucky, so 2 != 0
    # 86 would be similar to 68
    # 66: 2 lucky, 0 unlucky, invalid
    # 88: 2 lucky, 0 unlucky, invalid
    # 67: valid
    # 68: invalid
    # 76: 7(lucky0),6(lucky1) -> 1 vs 1 -> valid
    # 78: 7(lucky0),8(lucky1) -> 1 vs 1 -> valid
    # So from 30-70: 36,38,56,58,60,61,62,63,65,67,76,78 -> 12? 
    # Let's recalculate manually for 30-70:
    # 30: 0 lucky, 2 unlucky - invalid
    # 31: 0,2 - invalid
    # 32: 0,2 - invalid
    # 33: 0,2 - invalid
    # 34: contains 4 - invalid
    # 35: 0,2 - invalid
    # 36: 1,1 - valid (1)
    # 37: 0,2 - invalid
    # 38: 1,1 - valid (2)
    # 39: 0,2 - invalid
    # 40-49: contains 4 - invalid
    # 50: 0,2 - invalid
    # 51: 0,2 - invalid
    # 52: 0,2 - invalid
    # 53: 0,2 - invalid
    # 54: contains 4 - invalid
    # 55: 0,2 - invalid
    # 56: 1,1 - valid (3)
    # 57: 0,2 - invalid
    # 58: 1,1 - valid (4)
    # 59: 0,2 - invalid
    # 60: 1,1 - valid (5)
    # 61: 1,1 - valid (6)
    # 62: 1,1 - valid (7)
    # 63: 1,1 - valid (8)
    # 64: contains 4 - invalid
    # 65: 1,1 - valid (9)
    # 66: 2,0 - invalid (balance requires equal)
    # 67: 1,1 - valid (10)
    # 68: 2,0 - invalid
    # 69: 1,1 - valid? 6(lucky),9(not) -> 1 vs 1 -> valid (11)
    # 70: 0,2 - invalid
    # 71: 0,2 - invalid
    # 72: 0,2 - invalid
    # 73: 0,2 - invalid
    # 74: contains 4 - invalid
    # 75: 0,2 - invalid
    # 76: 1,1 - valid (12)
    # 77: 0,2 - invalid
    # 78: 1,1 - valid (13)
    # 79: 0,2 - invalid
    # But sample output says 11. Let me re-read condition.
    # "number of digits that are either 6 or 8 is the same as the number of digits that aren't."
    # For 69: digits 6 and 9. 6 is lucky. 9 is not 6 or 8. So lucky=1, not_lucky=1. Equal. Valid.
    # But sample says 11. Wait, 69 is in [66,69] test case.
    # Test 2: [66,69] -> 2. So 66,67,68,69. Which 2?
    # 66: lucky=2, not=0 -> invalid
    # 67: lucky=1, not=1 -> valid
    # 68: lucky=2, not=0 -> invalid
    # 69: lucky=1, not=1 -> valid
    # So 67,69 = 2. That matches.
    # So [30,70] should be 11. Let me recount:
    # 36,38,56,58,60,61,62,63,65,67,69,76,78 = 13? But output is 11.
    # Wait, 70 is the upper bound. 70 is not included? No, "inclusive".
    # Let's check 76,78. 76 is in [30,70]? No, 76 > 70. 78 > 70.
    # So only up to 70. 69 is included.
    # List: 36,38,56,58,60,61,62,63,65,67,69. That's 11. Correct.
    
    # So the test cases are:
    # 1. [30, 70] -> 11
    # 2. [66, 69] -> 2
    # 3. [100, 999] -> 0 (but 999 > 255, so we need to scale or adjust)
    
    # For our 8-bit version, we need scaled test cases:
    # Original constraint: 1 <= L <= R <= 10^200000 (huge)
    # We scale to 8-bit: 0-255
    # We need to select ranges that test the logic.
    # Let's pick small ranges:
    # Test 1: L=30, R=70 -> expected 11
    # Test 2: L=66, R=69 -> expected 2
    # Test 3: L=67, R=67 -> expected 1 (just 67)
    # Test 4: L=0, R=9 -> expected? 0 (no valid), 1 (1 digit, can't be equal), 2 (8? 1 lucky, 0 unlucky) -> 0
    # Test 5: L=16, R=18 -> 16 (valid? 1,6 -> 1 vs 1 yes), 17 (0,2 no), 18 (1,1 yes) -> 2
    
    test_cases = [
        (30, 70, 11),
        (66, 69, 2),
        (67, 67, 1),
        (0, 9, 0),
        (16, 18, 2)
    ]
    
    for i, (L, R, expected) in enumerate(test_cases):
        dut.L.value = L
        dut.R.value = R
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while not dut.done.value and timeout < 300:
            await RisingEdge(dut.clk)
            timeout += 1
        
        if timeout >= 300:
            raise TestFailure(f"Test {i+1}: Timeout waiting for done")
        
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"Test {i+1} (L={L}, R={R}): Expected {expected}, got {result}")
        
        print(f"Test {i+1}: L={L}, R={R}, Expected={expected}, Got={result} - PASS")
        await RisingEdge(dut.clk)
    
    print("All tests passed!")
