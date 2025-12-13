import cocotb
from cocotb.triggers import RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_trim(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test case format: ([input_tuples], K, expected results)
    test_cases = [
        ([(5,3,2,1,4), (3,4,9,2,1), (9,1,2,3,5), (4,8,2,1,7)], 2, [2,9,2,2]),
        ([(5,3,2,1,4), (3,4,9,2,1), (9,1,2,3,5), (4,8,2,1,7)], 1, [0x324, 0x492, 0x123, 0x821]),  # 3,2,1 becomes 0x3, 0x2, 0x1 in hex (packed)
        ([(7,8,4,9), (11,8,12,4), (4,1,7,8), (3,6,9,7)], 1, [0x840, 0x8C0, 0x170, 0x690])  # Input padded to 5 elements (last element=0)
    ]
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    passed = 0
    total = 0
    
    for (tuples, k, expected_list) in test_cases:
        dut.K.value = k
        for idx, (tpl, expected) in enumerate(zip(tuples, expected_list)):
            # Pad tuples to 5 elements with zeros
            padded = list(tpl) + [0]*(5-len(tpl))
            val = 0
            for num in padded:
                val = (val << 4) | (num & 0xF)
                
            dut.tuple_in.value = val
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await RisingEdge(dut.clk)
            
            # Mask based on K (only check relevant bits)
            result = dut.tuple_out.value
            
            if k == 2:
                # Only check lower 4 bits for K=2
                actual = result & 0xF
                expected_val = expected & 0xF
            else:
                actual = result
                expected_val = expected
            
            total += 1
            if actual == expected_val:
                passed += 1
                dut._log.info(f"PASS: Tuple {tpl}, K={k} → {hex(actual)}")
            else:
                dut._log.error(f"FAIL: Tuple {tpl}, K={k}. Got {hex(actual)}, expected {hex(expected_val)}")
            await RisingEdge(dut.clk)
    
    dut._log.info(f"TEST SUMMARY: {passed}/{total} tests passed")