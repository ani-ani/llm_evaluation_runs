import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray

@cocotb.test()
async def test_tuple_checker(dut):
    # Convert test cases to zero-padded 4x4 arrays
    def mk_input(t1, t2, t3=[0,0,0,0], t4=[0,0,0,0]):
        flat = t1 + t2 + t3 + t4
        val = 0
        for i, num in enumerate(flat):
            val |= num << (120 - i*8)
        return val
    
    test_cases = [
        (mk_input([11,22,33,0], [44,55,66,0]), 1), # Equal length (3+3)
        (mk_input([1,2,3,0], [4,5,6,7]), 0),       # Unequal (3 vs 4)
        (mk_input([1,2,0,0], [3,4,0,0]), 1),       # Equal (2+2)
        (mk_input([9,9,9,9], [8,8,8,8]), 1),       # Full-length (4+4)
        (mk_input([1,0,0,0], [2,3,0,0]), 0)        # Uneven (1 vs 2)
    ]
    
    passed = 0
    for input_val, expected in test_cases:
        dut.tuples.value = input_val
        await Timer(1, units='ns')
        result = dut.match_flag.value
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: {hex(input_val)} => {result}")
        else:
            dut._log.error(f"FAIL: {hex(input_val)} => {result}, expected {expected}")
    
    total = len(test_cases)
    dut._log.info(f"{passed}/{total} tests passed")
    assert passed == total