import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_haiku_solver(dut):
    """Test Haiku Solver Logic (5-7-5 syllable detection)"""
    
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_in.value = 0
    dut.char_valid.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # State definitions from Verilog
    IDLE = 0
    PARSE = 1
    CHECK = 2
    VALID = 3
    INVALID = 4
    
    # Test Cases
    # 1. Valid Haiku: "One two three. Four five six seven. Eight nine ten."
    # Syl: 1+1+1=3 (Fail) -> Let's use a real valid one.
    # "A B C D E." (1+1+1+1+1=5) "F G H I J K L." (1+1+1+1+1+1+1=7) "M N O P Q." (1+1+1+1+1=5)
    # Input: "A B C D E. F G H I J K L. M N O P Q."
    
    test_inputs = [
        ("A B C D E. F G H I J K L. M N O P Q.
", True),  # Valid (Each word 1 syllable)
        ("Blue Ridge mountain road. Leaves, glowing in autumn sun, fall in Virginia.
", True), # Valid (Example 1)
        ("Who would know if we had too few syllables?
", False), # Invalid
        ("International contest- motivation high Programmers have fun!.
", True), # Valid (Example 3)
        ("Programming contest is stressing us all out. International pain.
", False), # Invalid
    ]
    
    for test_str, expected_valid in test_inputs:
        dut._log.info(f"Testing: '{test_str.strip()}' Expecting: {'VALID' if expected_valid else 'INVALID'}")
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed characters
        for char in test_str:
            dut.char_in.value = ord(char)
            dut.char_valid.value = 1
            await RisingEdge(dut.clk)
        
        # Wait for CHECK state
        while dut.state_out.value == IDLE or dut.state_out.value == PARSE:
            await RisingEdge(dut.clk)
            # Timeout safety
            if dut.state_out.value == INVALID and not expected_valid:
                break
                
        # Wait for decision (VALID or INVALID)
        timeout = 0
        while dut.state_out.value not in [VALID, INVALID] and timeout < 20:
            await RisingEdge(dut.clk)
            timeout += 1
            
        final_state = int(dut.state_out.value)
        
        if expected_valid:
            if final_state != VALID:
                raise TestFailure(f"Expected VALID but got state {final_state}")
        else:
            if final_state != INVALID:
                raise TestFailure(f"Expected INVALID but got state {final_state}")
                
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
