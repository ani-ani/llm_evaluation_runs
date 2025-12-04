import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray

@cocotb.test()
async def test_append(dut):
    # Test cases adapted from original Python:
    test_cases = [
        # Tuple(9,10) + List[5,6,7]
        (LogicArray([9, 9], dtype='u4').value, LogicArray([5,6,7], dtype='u4').value, LogicArray([9,10,5,6,7], dtype='u4').value),
        # Tuple(10,11) + List[6,7,8]
        (LogicArray([10,11], dtype='u4').value, LogicArray([6,7,8], dtype='u4').value, LogicArray([10,11,6,7,8], dtype='u4').value),
        # Tuple(11,12) + List[7,8,9]
        (LogicArray([11,12], dtype='u4').value, LogicArray([7,8,9], dtype='u4').value, LogicArray([11,12,7,8,9], dtype='u4').value)
    ]

    passed = 0
    for tup, lst, expected in test_cases:
        # Set inputs
        for i in range(2):
            dut.tuple_array[i].value = (tup >> (4*i)) & 0xF
        for j in range(3):
            dut.list_array[j].value = (lst >> (4*j)) & 0xF
        
        await Timer(1, units='ns')
        
        # Collect output
        result = 0
        for k in range(5):
            result |= int(dut.result_array[k].value) << (4*k)
        
        # Compare with expected
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: Input ({tup>>4}, {tup&0xF}) + List({lst>>8}, {(lst>>4)&0xF}, {lst&0xF}) = {[(expected>>(4*i))&0xF for i in range(5)]}")
        else:
            expected_list = [(expected >> (4*i)) & 0xF for i in range(5)]
            actual_list = [(result >> (4*i)) & 0xF for i in range(5)]
            dut._log.error(f"FAIL: Input ({tup>>4}, {tup&0xF}) + List({lst>>8}, {(lst>>4)&0xF}, {lst&0xF})
  Expected {expected_list}
  Got {actual_list}")

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")