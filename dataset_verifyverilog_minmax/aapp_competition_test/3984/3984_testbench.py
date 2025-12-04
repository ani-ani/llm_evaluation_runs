import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_winner(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        ("abba", [0,1,1,0]),  # Mike, Ann, Ann, Mike
        ("cba", [0,0,0]),      # Mike, Mike, Mike
        ("a", [0]),            # Mike
        ("aa", [0,0]),          # Both Mike
        ("abc", [0,1,1])       # Mike, Ann, Ann
    ]
    
    total_tests = 0
    passed = 0
    
    for s, expected in test_cases:
        dut.start.value = 1
        dut.str_len.value = len(s)
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Shift in characters
        min_char = ord('z')
        actual_results = []
        for i, c in enumerate(s):
            char_val = ord(c)
            dut.char_in.value = char_val
            await RisingEdge(dut.clk)
            min_char = min(min_char, char_val)
            
        # Wait for processing completion
        for _ in range(len(s)+1):
            await RisingEdge(dut.clk)
        
        assert dut.done.value == 1, "Done not asserted after processing"
        total_tests += 1
        
        # Check results for string positions
        correct = True
        for i, exp in enumerate(expected):
            res_bit = (dut.results.value >> i) & 1
            if res_bit != exp:
                dut._log.error(
                    f"Test {s} failed at position {i}: got {res_bit}({'Ann' if res_bit else 'Mike'}), expected {'Ann' if exp else 'Mike'}")
                correct = False
        
        if correct:
            passed += 1
            dut._log.info(f"Test {s} passed")
        
        dut.rst_n.value = 0  # Reset for next test
        await ClockCycles(dut.clk, 2)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"Final: {passed}/{total_tests} tests passed")
    assert passed == total_tests