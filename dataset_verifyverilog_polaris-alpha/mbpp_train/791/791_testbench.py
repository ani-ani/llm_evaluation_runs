import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_tuple_filter(dut):
    # Generate clock
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases (data_in, mask_in, expected_data, expected_cnt)
    test_cases = [
        # Test 1: Original (1,5,7,(4,6),10)
        ([1,5,7,4,10,0,0,0], 0b11101000, [1,5,7,10,0,0,0,0], 4),
        # Test 2: Original (2,6,8,(5,7),11)
        ([2,6,8,5,11,0,0,0], 0b11101000, [2,6,8,11,0,0,0,0], 4),
        # Test 3: Original (3,7,9,(6,8),12)
        ([3,7,9,6,12,0,0,0], 0b11101000, [3,7,9,12,0,0,0,0], 4),
        # Test 4: Original (3,7,9,(6,8),(5,12),12)
        ([3,7,9,6,5,12,0,0], 0b11000110, [3,7,9,12,0,0,0,0], 4),
        # Edge case: all tuples
        ([1,2,3,4,5,6,7,8], 0b00000000, [0,0,0,0,0,0,0,0], 0),
        # Edge case: no tuples
        ([10,20,30,40,0,0,0,0], 0b11110000, [10,20,30,40,0,0,0,0], 4)
    ]
    
    passed = 0
    for data, mask, exp_data, exp_cnt in test_cases:
        # Apply inputs
        for i in range(8):
            dut.data_in[i].value = data[i]
        dut.mask_in.value = mask
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion (2 cycles)
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        
        # Verify outputs
        output_match = True
        for i in range(8):
            if int(dut.data_out[i].value) != exp_data[i]:
                output_match = False
        
        cnt_match = (int(dut.valid_cnt.value) == exp_cnt)
        done_ok = (dut.done.value == 1)
        
        if output_match and cnt_match and done_ok:
            passed += 1
            dut._log.info(f"PASS: Input {data},{bin(mask)} -> Output {exp_data},{exp_cnt}")
        else:
            dut._log.error(f"FAIL: Input {data},{bin(mask)}")
            if not output_match:
                actual = [int(dut.data_out[i].value) for i in range(8)]
                dut._log.error(f"  Data: got {actual}, expected {exp_data}")
            if not cnt_match:
                dut._log.error(f"  Count: got {int(dut.valid_cnt.value)}, expected {exp_cnt}")
            if not done_ok:
                dut._log.error(f"  Done signal: {int(dut.done.value)}, expected 1")
        
        await RisingEdge(dut.clk)
        
    # Test summary
    total = len(test_cases)
    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total, f"Failed {total-passed} tests"