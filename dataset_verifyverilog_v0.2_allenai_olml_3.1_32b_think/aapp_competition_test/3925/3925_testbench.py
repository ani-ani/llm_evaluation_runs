import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_zebra_solver(dut):
    """Test the zebra solver module"""
    
    # Create a clock with a 10ns period
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.load.value = 0
    dut.char_in.value = 0
    dut.char_index.value = 0
    
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper function to load a string
    async def load_string(s):
        dut._log.info(f"Loading string: {s}")
        dut.load.value = 1
        for i, char in enumerate(s):
            dut.char_index.value = i
            dut.char_in.value = ord(char)
            await RisingEdge(dut.clk)
        dut.load.value = 0
        await RisingEdge(dut.clk)
        
    # Helper function to run computation
    async def compute_and_check(s, expected):
        await load_string(s)
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while dut.done.value == 0:
            await RisingEdge(dut.clk)
            timeout += 1
            if timeout > 100:
                raise TestFailure("Timeout waiting for done signal")
        
        result = int(dut.max_len.value)
        dut._log.info(f"Input: '{s}' -> Result: {result} (Expected: {expected})")
        
        if result != expected:
            raise TestFailure(f"Mismatch for '{s}': got {result}, expected {expected}")

    # Test Cases
    # 1. bwwwbwwbw -> 5 (Example 1)
    await compute_and_check("bwwwbwwbw", 5)
    
    # 2. bwwbwwb -> 3 (Example 2)
    await compute_and_check("bwwbwwb", 3)
    
    # 3. bwb -> 3 (Full string is alternating)
    await compute_and_check("bwb", 3)
    
    # 4. wbbwbw -> 4 (Wrap around: w...w -> prefix 'w' + suffix 'bw' -> 1+3=4)
    # b w b w b w -> length 6? No, input is w b b w b w. 
    # Indices: 0:w, 1:b, 2:b, 3:w, 4:b, 5:w
    # Alternating sections: [0: w,b] len 2. [2: b,w,b,w] len 4. Max is 4.
    # Wrap check: s[0]='w', s[5]='w'. Same. No wrap.
    await compute_and_check("wbbwbw", 4)
    
    # 5. wbwbwb -> 6 (Full string alternating)
    await compute_and_check("wbwbwb", 6)
    
    # 6. www -> 1 (No alternation)
    await compute_and_check("www", 1)
    
    # 7. b -> 1 (Single character)
    await compute_and_check("b", 1)
    
    dut._log.info("All tests passed!")
