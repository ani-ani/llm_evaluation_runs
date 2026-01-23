import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock

@cocotb.test()
async def test_circular_shift(dut):
    """Test the circular shift module."""
    
    # Create a clock
    c = Clock(dut.clk, 10, 'ns')
    cocotb.start_soon(c.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.x.value = 0
    dut.shift.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper function to run a test case
    async def run_test(x_val, shift_val, expected_val, description):
        print(f"Running test: {description}")
        dut.x.value = x_val
        dut.shift.value = shift_val
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while dut.done.value == 0:
            await RisingEdge(dut.clk)
            timeout += 1
            if timeout > 60:
                print(f"  FAILED: Timeout for {description}")
                assert False, "Timeout"
        
        # Check result
        actual = int(dut.result.value)
        print(f"  Input: x={x_val}, shift={shift_val}")
        print(f"  Expected: {expected_val}, Actual: {actual}")
        
        assert actual == expected_val, f"Mismatch: {actual} != {expected_val}"
        await RisingEdge(dut.clk)
    
    # Test Cases (Adapted to hardware integer output)
    
    # Case 1: 100, 2 -> "001" -> 1
    # Python returns string "001", which is integer 1.
    await run_test(100, 2, 1, "100, 2 (Should reverse digits -> 001 -> 1)")
    
    # Case 2: 12, 2 -> "12" -> 12
    # Shift >= digits (2 digits, shift 2) -> Reversal (12 -> 21?) 
    # Wait, Python: 12, 2 -> "12". 
    # If shift > digits, reverse. 12 reversed is 21. 
    # But example says "12". 
    # Maybe logic: If shift % digits == 0, no change? 
    # Or if shift == digits, it full cycles? 
    # 12 -> digits [1, 2]. Shift 2. 
    # Reversal [2, 1] -> "21". 
    # Python doc says: "If shift > number of digits, return digits reversed."
    # But Example: circular_shift(12, 2) == "12".
    # This is ambiguous. 
    # Let's look at 12, 2. 12 has 2 digits. Shift 2. 
    # Shift >= digits. Reverse. 12 -> 21. 
    # The example says "12". 
    # Is it 12 -> 1, 2. Shift 2. 
    # Shift is cyclic? 
    # 12 -> [1,2]. Rotate right 2: 1->2, 2->1. Result [1,2]. -> 12. 
    # Ah, "Circular shift". 
    # Shift 1: 1->2, 2->1. Result [2,1] -> 21. 
    # Shift 2: 1->1, 2->2. Result [1,2] -> 12. 
    # Shift 3: 1->2, 2->1. Result [2,1] -> 21. 
    # So: if shift >= digits, we use shift % digits. 
    # BUT doc says "If shift > number of digits, return digits reversed." 
    # This conflicts with the example. 
    # 12, 2. digits=2, shift=2. shift == digits. 
    # Is > strictly greater? or >=? 
    # If >, then 2 is not > 2. So normal shift. 
    # Shift 2 on 2 digits -> (0+2)%2=0 -> '1', (1+2)%2=1 -> '2' -> 12. Matches.
    # 97, 8. Digits=2, shift=8. 8 > 2. Reversal. -> 79. Matches. 
    # 12, 1. Digits=2, shift=1. 1 < 2. Shift. (0+1)%2=1 -> '2', (1+1)%2=0 -> '1' -> 21. Matches.
    # 11, 101. Digits=2, shift=101. 101 > 2. Reversal. -> 11. Matches.
    # So Logic: 
    # If shift > digit_count: Reversal.
    # Else: Rotate by (shift % digit_count).
    
    # Case 3: 12, 2 -> "12" -> 12
    await run_test(12, 2, 12, "12, 2 (Shift == digits, no reversal, just normal rotation -> 12)")
    
    # Case 4: 97, 8 -> "79" -> 79
    await run_test(97, 8, 79, "97, 8 (Shift > digits, reverse -> 79)")
    
    # Case 5: 12, 1 -> "21" -> 21
    await run_test(12, 1, 21, "12, 1 (Shift < digits, rotate -> 21)")
    
    # Case 6: 11, 101 -> "11" -> 11
    await run_test(11, 101, 11, "11, 101 (Shift > digits, reverse -> 11)")
    
    print("All tests passed!")
