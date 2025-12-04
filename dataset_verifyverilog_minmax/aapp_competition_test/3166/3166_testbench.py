import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_tournament(dut):
    clock = Clock(dut.clk, 10, units="ns")  
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        # Test case 1: Expected output 1 (binary 001)
        {
            "adj": [0,0,1,1, 1,0,0,1, 0,1,0,0, 0,0,1,0],
            "S_mask": 0b0101,  # players 0 and 2 disqualified
            "expected": 0b001   # k'=1, possible
        },
        # Test case 2: Expected impossible (binary 100)
        {
            "adj": [0,0,1,1, 1,0,0,1, 0,1,0,0, 0,0,1,0],
            "S_mask": 0b0110,  # players 1 and 2 disqualified
            "expected": 0b100   # impossible
        },
        # Test case 3: Custom 4-player scenario
        {
            "adj": [0,1,0,0, 0,0,1,0, 1,0,0,1, 1,1,0,0],
            "S_mask": 0b1001,  # players 0 and 3 disqualified
            "expected": 0b001   # k'=1
        }
    ]
    
    passed = 0
    for idx, tc in enumerate(test_cases):
        # Apply inputs
        dut.adj_matrix.value = int(''.join(map(str,tc['\\adj'])),2)
        dut.original_S_mask.value = tc['\\S_mask']
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (max 100 cycles)
        for _ in range(100):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        # Verify output
        actual = dut.result.value
        if actual == tc['\\expected']:
            passed += 1
        else:
            dut._log.error(f"Test {idx+1} failed: Got {bin(actual)}, expected {bin(tc['\\expected'])}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)