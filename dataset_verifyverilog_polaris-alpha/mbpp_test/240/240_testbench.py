import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_list_replacer(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    
    # Reset sequence
    dut.start.value = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    test_cases = [
        # Test 1
        {
            "list1": [1,3,5,7,9,10] + [0]*2,
            "len1": 6,
            "list2": [2,4,6,8] + [0]*4,
            "len2": 4,
            "expected": [1,3,5,7,9,2,4,6,8] + [0]*6,
            "expected_len": 9
        },
        # Test 2
        {
            "list1": [1,2,3,4,5] + [0]*3,
            "len1": 5,
            "list2": [5,6,7,8] + [0]*4,
            "len2": 4,
            "expected": [1,2,3,4,5,6,7,8] + [0]*7,
            "expected_len": 8
        },
        # Test 3 (ASCII values: r=114,b=98,g=103,y=121)
        {
            "list1": [114,98,103] + [0]*5,    # "red","blue","green"
            "len1": 3,
            "list2": [121] + [0]*7,           # "yellow"
            "len2": 1,
            "expected": [114,98,121] + [0]*12, 
            "expected_len": 3
        },
        # Edge case: merge leads to truncation
        {
            "list1": list(range(12)) + [0]*4,
            "len1": 12,   
            "list2": list(range(5)) + [0]*3,
            "len2": 5,
            "expected": list(range(11)) + list(range(5))[:4],  # Keep 15 elements
            "expected_len": 15
        }
    ]

    passed = 0
    for tc in test_cases:
        # Apply inputs
        for i in range(8):
            dut.list1_in[i].value = tc["list1"][i]
            dut.list2_in[i].value = tc["list2"][i]
        dut.len1_in.value = tc["len1"]
        dut.len2_in.value = tc["len2"]
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        await RisingEdge(dut.clk)  # Done should be high now
        
        # Check outputs
        assert dut.done.value == 1, "Done not asserted"
        assert dut.result_len_out.value == tc["expected_len"], \
            f"Len error: Got {dut.result_len_out.value}, Expected {tc['expected_len']}"
        
        # Verify array contents up to declared length
        all_match = True
        for i in range(tc['expected_len']):
            if i < 15:  # Only check first 15 elements
                if dut.result_out[i].value != tc["expected"][i]:
                    all_match = False
                    break
        
        if all_match:
            passed += 1
            dut._log.info(f"PASS: TC {passed}")
        else:
            dut._log.error(f"FAIL: Data mismatch. Expected {tc['expected'][:tc['expected_len']]}")
            
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)