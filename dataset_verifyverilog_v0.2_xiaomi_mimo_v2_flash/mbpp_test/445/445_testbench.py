import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer

@cocotb.test()
async def test_index_multiplication(dut):
    """Test index-wise multiplication of tuple elements"""
    
    # Test Case 1: ((1, 3), (4, 5), (2, 9), (1, 10)) × ((6, 7), (3, 9), (1, 1), (7, 3))
    # Pair 1: (1, 3) × (6, 7) = (6, 21)
    dut.tuple_in_1.value = 0x00010003  # (1, 3)
    dut.tuple_in_2.value = 0x00060007  # (6, 7)
    await Timer(10, units='ns')
    result = dut.result_tuple.value
    print(f"Test 1 Pair 1: Expected (6, 21), Got ({result.value >> 16}, {result.value & 0xFFFF})")
    assert (result.value >> 16) == 6 and (result.value & 0xFFFF) == 21, "Test 1 Pair 1 failed"
    
    # Pair 2: (4, 5) × (3, 9) = (12, 45)
    dut.tuple_in_1.value = 0x00040005  # (4, 5)
    dut.tuple_in_2.value = 0x00030009  # (3, 9)
    await Timer(10, units='ns')
    result = dut.result_tuple.value
    print(f"Test 1 Pair 2: Expected (12, 45), Got ({result.value >> 16}, {result.value & 0xFFFF})")
    assert (result.value >> 16) == 12 and (result.value & 0xFFFF) == 45, "Test 1 Pair 2 failed"
    
    # Pair 3: (2, 9) × (1, 1) = (2, 9)
    dut.tuple_in_1.value = 0x00020009  # (2, 9)
    dut.tuple_in_2.value = 0x00010001  # (1, 1)
    await Timer(10, units='ns')
    result = dut.result_tuple.value
    print(f"Test 1 Pair 3: Expected (2, 9), Got ({result.value >> 16}, {result.value & 0xFFFF})")
    assert (result.value >> 16) == 2 and (result.value & 0xFFFF) == 9, "Test 1 Pair 3 failed"
    
    # Pair 4: (1, 10) × (7, 3) = (7, 30)
    dut.tuple_in_1.value = 0x0001000A  # (1, 10)
    dut.tuple_in_2.value = 0x00070003  # (7, 3)
    await Timer(10, units='ns')
    result = dut.result_tuple.value
    print(f"Test 1 Pair 4: Expected (7, 30), Got ({result.value >> 16}, {result.value & 0xFFFF})")
    assert (result.value >> 16) == 7 and (result.value & 0xFFFF) == 30, "Test 1 Pair 4 failed"
    
    # Test Case 2: ((2, 4), (5, 6), (3, 10), (2, 11)) × ((7, 8), (4, 10), (2, 2), (8, 4))
    # Pair 1: (2, 4) × (7, 8) = (14, 32)
    dut.tuple_in_1.value = 0x00020004  # (2, 4)
    dut.tuple_in_2.value = 0x00070008  # (7, 8)
    await Timer(10, units='ns')
    result = dut.result_tuple.value
    print(f"Test 2 Pair 1: Expected (14, 32), Got ({result.value >> 16}, {result.value & 0xFFFF})")
    assert (result.value >> 16) == 14 and (result.value & 0xFFFF) == 32, "Test 2 Pair 1 failed"
    
    # Pair 2: (5, 6) × (4, 10) = (20, 60)
    dut.tuple_in_1.value = 0x00050006  # (5, 6)
    dut.tuple_in_2.value = 0x0004000A  # (4, 10)
    await Timer(10, units='ns')
    result = dut.result_tuple.value
    print(f"Test 2 Pair 2: Expected (20, 60), Got ({result.value >> 16}, {result.value & 0xFFFF})")
    assert (result.value >> 16) == 20 and (result.value & 0xFFFF) == 60, "Test 2 Pair 2 failed"
    
    # Pair 3: (3, 10) × (2, 2) = (6, 20)
    dut.tuple_in_1.value = 0x0003000A  # (3, 10)
    dut.tuple_in_2.value = 0x00020002  # (2, 2)
    await Timer(10, units='ns')
    result = dut.result_tuple.value
    print(f"Test 2 Pair 3: Expected (6, 20), Got ({result.value >> 16}, {result.value & 0xFFFF})")
    assert (result.value >> 16) == 6 and (result.value & 0xFFFF) == 20, "Test 2 Pair 3 failed"
    
    # Pair 4: (2, 11) × (8, 4) = (16, 44)
    dut.tuple_in_1.value = 0x0002000B  # (2, 11)
    dut.tuple_in_2.value = 0x00080004  # (8, 4)
    await Timer(10, units='ns')
    result = dut.result_tuple.value
    print(f"Test 2 Pair 4: Expected (16, 44), Got ({result.value >> 16}, {result.value & 0xFFFF})")
    assert (result.value >> 16) == 16 and (result.value & 0xFFFF) == 44, "Test 2 Pair 4 failed"
    
    # Test Case 3: ((3, 5), (6, 7), (4, 11), (3, 12)) × ((8, 9), (5, 11), (3, 3), (9, 5))
    # Pair 1: (3, 5) × (8, 9) = (24, 45)
    dut.tuple_in_1.value = 0x00030005  # (3, 5)
    dut.tuple_in_2.value = 0x00080009  # (8, 9)
    await Timer(10, units='ns')
    result = dut.result_tuple.value
    print(f"Test 3 Pair 1: Expected (24, 45), Got ({result.value >> 16}, {result.value & 0xFFFF})")
    assert (result.value >> 16) == 24 and (result.value & 0xFFFF) == 45, "Test 3 Pair 1 failed"
    
    # Pair 2: (6, 7) × (5, 11) = (30, 77)
    dut.tuple_in_1.value = 0x00060007  # (6, 7)
    dut.tuple_in_2.value = 0x0005000B  # (5, 11)
    await Timer(10, units='ns')
    result = dut.result_tuple.value
    print(f"Test 3 Pair 2: Expected (30, 77), Got ({result.value >> 16}, {result.value & 0xFFFF})")
    assert (result.value >> 16) == 30 and (result.value & 0xFFFF) == 77, "Test 3 Pair 2 failed"
    
    # Pair 3: (4, 11) × (3, 3) = (12, 33)
    dut.tuple_in_1.value = 0x0004000B  # (4, 11)
    dut.tuple_in_2.value = 0x00030003  # (3, 3)
    await Timer(10, units='ns')
    result = dut.result_tuple.value
    print(f"Test 3 Pair 3: Expected (12, 33), Got ({result.value >> 16}, {result.value & 0xFFFF})")
    assert (result.value >> 16) == 12 and (result.value & 0xFFFF) == 33, "Test 3 Pair 3 failed"
    
    # Pair 4: (3, 12) × (9, 5) = (27, 60)
    dut.tuple_in_1.value = 0x0003000C  # (3, 12)
    dut.tuple_in_2.value = 0x00090005  # (9, 5)
    await Timer(10, units='ns')
    result = dut.result_tuple.value
    print(f"Test 3 Pair 4: Expected (27, 60), Got ({result.value >> 16}, {result.value & 0xFFFF})")
    assert (result.value >> 16) == 27 and (result.value & 0xFFFF) == 60, "Test 3 Pair 4 failed"
    
    # Edge case: Multiplication by zero
    dut.tuple_in_1.value = 0x0005000A  # (5, 10)
    dut.tuple_in_2.value = 0x00000000  # (0, 0)
    await Timer(10, units='ns')
    result = dut.result_tuple.value
    print(f"Edge case: (5, 10) × (0, 0) = ({result.value >> 16}, {result.value & 0xFFFF})")
    assert (result.value >> 16) == 0 and (result.value & 0xFFFF) == 0, "Zero multiplication failed"
    
    # Edge case: Larger numbers
    dut.tuple_in_1.value = 0x010000FF  # (256, 255)
    dut.tuple_in_2.value = 0x00020003  # (2, 3)
    await Timer(10, units='ns')
    result = dut.result_tuple.value
    print(f"Edge case: (256, 255) × (2, 3) = ({result.value >> 16}, {result.value & 0xFFFF})")
    assert (result.value >> 16) == 512 and (result.value & 0xFFFF) == 765, "Large multiplication failed"
    
    print("
All tests passed successfully!")
    print("Summary: 14/14 tests passed")
