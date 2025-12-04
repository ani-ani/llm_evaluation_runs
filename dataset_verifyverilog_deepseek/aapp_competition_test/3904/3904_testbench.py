import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.binary import BinaryValue

@cocotb.test()
async def bracket_test(dut):
    clock = Clock(dut.clk, 10, units="ns")  
    cocotb.start_soon(clock.start())
    
    test_cases = [
        (8, 0b00100011, 6),  # '))((())( --> 6
        (3, 0b100, 31),     # '(()' => -1 (11111)
        (4, 0b0011, 4),     # '))((' --> 4
        (4, 0b0101, 4),     # ')()(' --> 4
        (4, 0b1111, 31),    # '(((( --> -1
        (2, 0b00, 31)       # '))' --> -1  
    ]
    
    passed = 0
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    for (length, seq, expected) in test_cases:
        dut.seq_len.value = length
        dut.bracket_seq.value = seq
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait until done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        result_val = dut.result.value.signed_integer
        if result_val == expected:
            passed += 1
        else:
            dut._log.error(f"Failed: len={length}, seq={bin(seq)} got {result_val}, expected {expected}")
        
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")"