import cocotb
from cocotb.triggers import Timer
from cocotb.types import LogicArray

@cocotb.test()
async def test_counter(dut):
    # Test case 1: Find '1' in numerical lists
    dut.target_element.value = ord('1') if isinstance('1', str) else 1  # Handle both types
    dut.sublists.value = [
        [1 if isinstance(1, int) else ord('1'), 3, 0, 0],
        [5, 7, 0, 0],
        [1 if isinstance(1, int) else ord('1'), 11, 0, 0],
        [1 if isinstance(1, int) else ord('1'), 15, 7, 0]
    ]
    dut.valid_mask.value = [
        [1, 1, 0, 0],
        [1, 1, 0, 0],
        [1, 1, 0, 0],
        [1, 1, 1, 0]
    ]
    await Timer(1, 'ns')
    assert dut.count.value == 3, f"Test 1 failed: Expected 3, got {dut.count.value}"

    # Test case 2: Find 'A' in character lists
    dut.target_element.value = ord('A')
    dut.sublists.value = [
        [ord('A'), ord('B'), 0, 0],
        [ord('A'), ord('C'), 0, 0],
        [ord('A'), ord('D'), ord('E'), 0],
        [ord('B'), ord('C'), ord('D'), 0]
    ]
    dut.valid_mask.value = [
        [1, 1, 0, 0],
        [1, 1, 0, 0],
        [1, 1, 1, 0],
        [1, 1, 1, 0]
    ]
    await Timer(1, 'ns')
    assert dut.count.value == 3, f"Test 2 failed: Expected 3, got {dut.count.value}"

    # Test case 3: Find 'E' in character lists
    dut.target_element.value = ord('E')
    await Timer(1, 'ns')
    assert dut.count.value == 1, f"Test 3 failed: Expected 1, got {dut.count.value}"

    # Test case 4: Edge case - no matches
    dut.target_element.value = ord('X')
    await Timer(1, 'ns')
    assert dut.count.value == 0, f"Test 4 failed: Expected 0, got {dut.count.value}"

    # Test case 5: All sublists match
    dut.target_element.value = ord('A')
    dut.sublists.value = [[ord('A')] * 4] * 4
    dut.valid_mask.value = [[1,0,0,0]] * 4  # Only first element matters
    await Timer(1, 'ns')
    assert dut.count.value == 4, f"Test 5 failed: Expected 4, got {dut.count.value}"

    dut._log.info(f"{5}/{5} tests passed")