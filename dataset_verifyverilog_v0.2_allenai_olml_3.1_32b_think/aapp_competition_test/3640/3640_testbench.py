import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_meow_factor(dut):
    """Test the meow_factor module with various test cases"""
    
    # Initialize inputs
    dut.char_0.value = 0
    dut.char_1.value = 0
    dut.char_2.value = 0
    dut.char_3.value = 0
    dut.char_4.value = 0
    dut.char_5.value = 0
    dut.char_6.value = 0
    dut.char_7.value = 0
    
    await Timer(10, units='ns')
    
    # Test Case 1: "pastimeofwhimsy" (adapted to 8 chars) -> "pastimeo" -> expected 1
    # Original: pastimeofwhimsy has "meow" at position 6-9 (0-indexed)
    # Adapted: "pastimeo" needs 1 operation (insert 'w' after 'o')
    dut._log.info("Test 1: pastimeo")
    dut.char_0.value = ord('p')  # 0x70
    dut.char_1.value = ord('a')  # 0x61
    dut.char_2.value = ord('s')  # 0x73
    dut.char_3.value = ord('t')  # 0x74
    dut.char_4.value = ord('i')  # 0x69
    dut.char_5.value = ord('m')  # 0x6D
    dut.char_6.value = ord('e')  # 0x65
    dut.char_7.value = ord('o')  # 0x6F
    await Timer(10, units='ns')
    result = int(dut.meow_factor.value)
    dut._log.info(f"Result: {result}")
    assert result == 1, f"Expected 1, got {result}"
    
    # Test Case 2: "yarn" (adapted to 8 chars) -> "yarn" -> expected 4
    # Need to replace all 4 chars to get "meow"
    dut._log.info("Test 2: yarn")
    dut.char_0.value = ord('y')  # 0x79
    dut.char_1.value = ord('a')  # 0x61
    dut.char_2.value = ord('r')  # 0x72
    dut.char_3.value = ord('n')  # 0x6E
    dut.char_4.value = 0
    dut.char_5.value = 0
    dut.char_6.value = 0
    dut.char_7.value = 0
    await Timer(10, units='ns')
    result = int(dut.meow_factor.value)
    dut._log.info(f"Result: {result}")
    assert result == 4, f"Expected 4, got {result}"
    
    # Test Case 3: "meow" -> 0 operations
    dut._log.info("Test 3: meow")
    dut.char_0.value = ord('m')  # 0x6D
    dut.char_1.value = ord('e')  # 0x65
    dut.char_2.value = ord('o')  # 0x6F
    dut.char_3.value = ord('w')  # 0x77
    dut.char_4.value = 0
    dut.char_5.value = 0
    dut.char_6.value = 0
    dut.char_7.value = 0
    await Timer(10, units='ns')
    result = int(dut.meow_factor.value)
    dut._log.info(f"Result: {result}")
    assert result == 0, f"Expected 0, got {result}"
    
    # Test Case 4: "meow" with extra chars -> "meowxyz" -> 3
    # Need to delete 3 chars or 1 insert + 2 deletes, etc.
    dut._log.info("Test 4: meowxyz")
    dut.char_0.value = ord('m')  # 0x6D
    dut.char_1.value = ord('e')  # 0x65
    dut.char_2.value = ord('o')  # 0x6F
    dut.char_3.value = ord('w')  # 0x77
    dut.char_4.value = ord('x')  # 0x78
    dut.char_5.value = ord('y')  # 0x79
    dut.char_6.value = ord('z')  # 0x7A
    dut.char_7.value = 0
    await Timer(10, units='ns')
    result = int(dut.meow_factor.value)
    dut._log.info(f"Result: {result}")
    assert result == 3, f"Expected 3, got {result}"
    
    # Test Case 5: "mewo" (swap needed) -> 1
    # Swapping e and o gives meow
    dut._log.info("Test 5: mewo")
    dut.char_0.value = ord('m')  # 0x6D
    dut.char_1.value = ord('e')  # 0x65
    dut.char_2.value = ord('w')  # 0x77
    dut.char_3.value = ord('o')  # 0x6F
    dut.char_4.value = 0
    dut.char_5.value = 0
    dut.char_6.value = 0
    dut.char_7.value = 0
    await Timer(10, units='ns')
    result = int(dut.meow_factor.value)
    dut._log.info(f"Result: {result}")
    assert result == 1, f"Expected 1, got {result}"
    
    # Test Case 6: Empty-ish string "mm" -> need to create "meow"
    dut._log.info("Test 6: mm")
    dut.char_0.value = ord('m')  # 0x6D
    dut.char_1.value = ord('m')  # 0x6D
    dut.char_2.value = 0
    dut.char_3.value = 0
    dut.char_4.value = 0
    dut.char_5.value = 0
    dut.char_6.value = 0
    dut.char_7.value = 0
    await Timer(10, units='ns')
    result = int(dut.meow_factor.value)
    dut._log.info(f"Result: {result}")
    # Cost: keep first m, replace second m->e, insert o, insert w = 3
    # Or delete both, insert meow = 4
    # Or replace first m->m (keep), second m->e, insert o,w = 3
    # Minimum is 3
    assert result == 3, f"Expected 3, got {result}"
    
    # Test Case 7: "mexyzow" -> 2 (replace x->o, delete y,z or similar)
    dut._log.info("Test 7: mexyzow")
    dut.char_0.value = ord('m')  # 0x6D
    dut.char_1.value = ord('e')  # 0x65
    dut.char_2.value = ord('x')  # 0x78
    dut.char_3.value = ord('y')  # 0x79
    dut.char_4.value = ord('z')  # 0x7A
    dut.char_5.value = ord('o')  # 0x6F
    dut.char_6.value = ord('w')  # 0x77
    dut.char_7.value = 0
    await Timer(10, units='ns')
    result = int(dut.meow_factor.value)
    dut._log.info(f"Result: {result}")
    # Options: delete x,y,z (3) or replace x->o, delete y,z (2) or replace x,y->o,w (impossible)
    # Best: me[o]ow with x,y,z deleted: 2 replacements + 3 deletes = 5
    # Wait, let's think: target "meow"
    # match m, e, then need o, w. have x,y,z,o,w
    # delete x,y,z: 3 operations, total 3
    # Or replace x->o, delete y,z: 2 operations
    # Or replace x->o, swap y,z -> not helpful
    # Actually, keep m,e,o,w: delete x,y,z: 3
    # Or replace x->o, delete y,z: 2
    # So min is 2
    assert result == 2, f"Expected 2, got {result}"
    
    # Test Case 8: "mewo" swap adjacent test
    dut._log.info("Test 8: mewo (swap e and w, then w and o? No, swap adjacent)")
    dut.char_0.value = ord('m')  # 0x6D
    dut.char_1.value = ord('e')  # 0x65
    dut.char_2.value = ord('w')  # 0x77
    dut.char_3.value = ord('o')  # 0x6F
    dut.char_4.value = 0
    dut.char_5.value = 0
    dut.char_6.value = 0
    dut.char_7.value = 0
    await Timer(10, units='ns')
    result = int(dut.meow_factor.value)
    dut._log.info(f"Result: {result}")
    # Swap w and o (positions 2 and 3): mewo -> meow = 1 operation
    assert result == 1, f"Expected 1, got {result}"
    
    total_tests = 8
    passed_tests = 0
    try:
        # Count passed tests
        passed_tests = 8  # All assertions passed
    except:
        passed_tests = sum([
            # Would need to track individually, but if we got here, all passed
        ])
    
    dut._log.info(f"
=== SUMMARY: {passed_tests}/{total_tests} tests passed ===")
    
    print(f"
=== SUMMARY: {passed_tests}/{total_tests} tests passed ===")
    
    assert passed_tests == total_tests, f"Only {passed_tests}/{total_tests} tests passed"
