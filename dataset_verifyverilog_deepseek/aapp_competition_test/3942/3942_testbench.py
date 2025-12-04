import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_balanced_paren(dut):
    # Define test cases (input string, expected output counts, expect_error)
    test_cases = [
        ("(((#)((#", [1,2,0,0,0,0,0,0], False),  # Truncated to 8 chars
        ("()((#((#", [1,1,0,0,0,0,0,0], False), # Test case 2 truncated
        ("##((())", [1,5,0,0,0,0,0,0], False),   # Second # gets remaining
        ("((((#)))", [1,0,0,0,0,0,0,0], True),   # Becomes unbalanced
        ("(#)", [0,0,0,0,0,0,0,0], True),        # Invalid when padded
    ]
    
    # Initialize clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    passed = 0
    total = len(test_cases)
    
    for s, expected, expect_error in test_cases:
        # Pad input to 8 characters with nulls (ASCII 0)
        s_padded = s.ljust(8, '\\0')
        
        # Reset device
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        
        # Load input characters
        for i in range(8):
            dut.char[i].value = ord(s_padded[i])
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait 9 cycles for completion
        for _ in range(9):
            await RisingEdge(dut.clk)
        
        # Check outputs
        if dut.valid.value != 1:
            raise TestFailure(f"valid not asserted for input: {s}")
        
        if dut.error.value != expect_error:
            msg = f"Error {'expected' if expect_error else 'unexpected'} for input: {s}
"
            raise TestFailure(msg)
        
        if not expect_error:
            counts_match = True
            for i in range(8):
                if dut.replace_counts[i].value != expected[i]:
                    counts_match = False
                    break
            
            if counts_match:
                passed += 1
            else:
                actual = [dut.replace_counts[i].value for i in range(8)]
                raise TestFailure(f"Test failed: Input '{s}' Expected {expected} Got {actual}")
        else:
            passed += 1
    
    dut._log.info(f"{passed}/{total} tests passed")
