import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_dragon(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    test_vectors = [
        # Input seq (binary LSB first), expected output
        # Original example (scaled): [1,2,1,2] → extended to 8 elements
        (0b10101010, 8), # Pattern 1,2,1,2,... → optimal LNDS=8
        # All type 1
        (0b00000000, 8), # All '1' → LNDS=8
        # All type 2
        (0b11111111, 8), # All '2' → LNDS=8
        # Mixed pattern
        (0b11110000, 5), # [2,2,2,2,1,1,1,1] → LNDS=4(max before reverse) → reversed becomes [1,1,1,1,2,2,...,0]
        # Edge case: reversal needed at center
        (0b11000011, 6) # [2,2,1,1,1,1,2,2] → optimal LNDS=6 after reversal
    ]
    
    passed = 0
    total = len(test_vectors)
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(15, units="ns")
    dut.rst_n.value = 1
    
    for seq, expected in test_vectors:
        # Apply test vector
        dut.seq.value = seq
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait 8 cycles for computation
        for _ in range(8):
            await RisingEdge(dut.clk)
        
        # Wait 1 cycle for result latch
        await RisingEdge(dut.clk)
        
        if dut.done.value == 1 and dut.max_length.value == expected:
            passed += 1
        else:
            dut._log.error(f"Test failed: seq={bin(seq)} got {dut.max_length.value}, expected {expected}")
    
    dut._log.info(f"{passed}/{total} tests passed")