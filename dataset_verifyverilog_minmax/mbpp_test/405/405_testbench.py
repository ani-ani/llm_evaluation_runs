import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray

@cocotb.test()
async def test_search(dut):
    # Test cases adapted to 8-bit values
    # Original: ("w",3,"r","e","s","o","u","r","c","e") + search elements
    test_cases = [
        # Test 1: Search 'r' (present)
        ([0x77, 3, 0x72, 0x65, 0x73, 0x6F, 0x75, 0x72, 0x63, 0x65], 0x72, 1),
        # Test 2: Search '5' (absent)
        ([0x77, 3, 0x72, 0x65, 0x73, 0x6F, 0x75, 0x72, 0x63, 0x65], 0x35, 0),
        # Test 3: Search 3 (present)
        ([0x77, 3, 0x72, 0x65, 0x73, 0x6F, 0x75, 0x72, 0x63, 0x65], 3, 1),
        # Edge case: Search 0 (absent)
        ([0x77, 3, 0x72, 0x65, 0x73, 0x6F, 0x75, 0x72, 0x63, 0x65], 0, 0)
    ]
    
    passed = 0
    for tuple_data, search_val, expected in test_cases:
        dut.search_element.value = search_val
        for i in range(10):
            dut.tuple_array[i].value = tuple_data[i]
        await Timer(1, units='ns')
        result = int(dut.found.value)
        if result == expected:
            passed += 1
            dut._log.info(f"PASS: Search {search_val} (0x{search_val:02X}) - Expected {expected}")
        else:
            dut._log.error(f"FAIL: Search {search_val} (0x{search_val:02X}) - Got {result}, Expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")