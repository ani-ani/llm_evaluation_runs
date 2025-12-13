import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_balance_checker(dut):
    # Character encodings
    L_PAREN = 0b000
    R_PAREN = 0b001
    L_BRACE = 0b010
    R_BRACE = 0b011
    L_BRACKET = 0b100
    R_BRACKET = 0b101
    INVALID = 0b111
    
    # Test cases (encoded expressions, expected result)
    test_cases = [
        # Test 1: "{()}[{}]"
        ([L_BRACE, L_PAREN, R_PAREN, R_BRACE, L_BRACKET, L_BRACE, R_BRACE, R_BRACKET] + [INVALID]*8, True),
        # Test 2: "{()}[{]"
        ([L_BRACE, L_PAREN, R_PAREN, R_BRACE, L_BRACKET, L_BRACE, R_BRACKET] + [INVALID]*9, False),
        # Test 3: "{()}[{}][]({})"
        ([L_BRACE, L_PAREN, R_PAREN, R_BRACE, L_BRACKET, L_BRACE, R_BRACE, R_BRACKET, 
          L_BRACKET, R_BRACKET, L_PAREN, L_BRACE, R_BRACE, R_PAREN] + [INVALID]*2, True),
        # Additional tests
        ([] + [INVALID]*16, True),  # Empty 
        ([L_PAREN]*16, False),       # All open
        ([R_PAREN]*16, False)        # All close
    ]
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    passed = 0
    total = len(test_cases)
    
    for expr, expected in test_cases:
        # Apply reset
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load test vector
        dut.start.value = 1
        for i, char_val in enumerate(expr):
            dut.expr[i].value = char_val
        
        # Start processing
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait 18 cycles (processing + result)
        for _ in range(18):
            await RisingEdge(dut.clk)
        
        # Check result
        if int(dut.result.value) == expected:
            passed += 1
            dut._log.info(f"PASS: exp={expected}, got {dut.result.value}")
        else:
            dut._log.error(f"FAIL: expr={expr[:5]}... expected {expected}, got {dut.result.value}")
    
    dut._log.info(f"{passed}/{total} tests passed")