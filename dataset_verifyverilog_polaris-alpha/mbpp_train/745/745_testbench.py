import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

async def reset_dut(dut):
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test()
async def test_divisible_checker(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    await reset_dut(dut)
    
    test_cases = [
        {'start': 1, 'end': 22, 'expected': [1,2,3,4,5,6,7,8,9,11,12,15,22]},
        {'start': 20, 'end': 25, 'expected': [22,24]},
        {'start': 240, 'end': 245, 'expected': [240, 242, 244]}
    ]
    
    passed = 0
    total = len(test_cases)
    
    for case in test_cases:
        dut.start_num.value = case['start']
        dut.end_num.value = case['end']
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        while dut.done.value == 0:
            await RisingEdge(dut.clk)
        
        # Collect results
        found = []
        for i in range(16):
            if i < dut.count.value:
                found.append(int(dut.results[i].value))
        
        expected_sorted = sorted(case['expected'])
        found_sorted = sorted(found)
        
        if len(found_sorted) == len(expected_sorted) and \
           all(x == y for x,y in zip(found_sorted, expected_sorted)):
            dut._log.info(f"PASS: Range {case['start']}-{case['end']} {found_sorted}")
            passed += 1
        else:
            dut._log.error(f"FAIL: Range {case['start']}-{case['end']} | Expected {expected_sorted}, got {found_sorted}")
        
        await reset_dut(dut)
    
    dut._log.info(f"{passed}/{total} test cases passed")
    assert passed == total