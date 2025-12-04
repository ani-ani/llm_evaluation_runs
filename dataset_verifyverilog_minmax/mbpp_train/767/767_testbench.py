import cocotb
from cocotb.triggers import Timer
import itertools

@cocotb.test()
async def test_pair_counter(dut):
    test_cases = [
        {"data": [1,1,1,1], "sum": 2, "expected": 6},
        {"data": [1,5,7,-1,5], "sum": 6, "expected": 3},
        {"data": [1,-2,3], "sum": 1, "expected": 1},
        {"data": [-1,-2,3], "sum": -3, "expected": 1}
    ]
    
    passed = 0

    for case in test_cases:
        / Zero out all elements first
        for i in range(8):
            getattr(dut, f"element_{i}").value = 0
            
        / Set active elements
        num_elements = len(case["data"])
        for i in range(num_elements):
            val = case["data"][i]
            val_2c = val & 0xFF if val >= 0 else (1 << 8) + val  / Two's complement conversion
            getattr(dut, f"element_{i}").value = val_2c
            
        dut.target_sum.value = case["sum"] & 0xFF if case["sum"] >=0 else (1<<8) + case["sum"]
        dut.valid_elements.value = num_elements
        
        await Timer(1, units='ns')
        
        actual = dut.pair_count.value.integer
        print_str = f"Input {case['data']} sum={case['sum']}: Expected {case['expected']}, Got {actual}"
        
        if actual == case["expected"]:
            dut._log.info(f"PASS: {print_str}")
            passed += 1
        else:
            dut._log.error(f"FAIL: {print_str}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")