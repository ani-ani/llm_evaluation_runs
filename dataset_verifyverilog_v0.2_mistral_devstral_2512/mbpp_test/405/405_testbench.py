import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer

@cocotb.test()
async def test_tuple_search(dut):
    """Test tuple element existence check"""
    
    # Helper function to convert tuple elements to byte array
    def tuple_to_bytes(tup):
        result = []
        for item in tup:
            if isinstance(item, str):
                # ASCII character
                result.append(ord(item))
            elif isinstance(item, int):
                # Small integer (0-255)
                result.append(item & 0xFF)
        return result
    
    # Helper function to pack bytes into 80-bit array
    def pack_array(bytes_list, valid_count):
        packed = 0
        for i, byte_val in enumerate(bytes_list):
            packed |= (byte_val << (8 * i))
        # Pad with zeros for remaining elements
        return packed
    
    # Test 1: Search for 'r' (0x72) in tuple ("w", 3, "r", "e", "s", "o", "u", "r", "c", "e")
    # Expected: True (exists at positions 2 and 7)
    dut._log.info("Test 1: Searching for 'r' (0x72)")
    tup1 = ("w", 3, "r", "e", "s", "o", "u", "r", "c", "e")
    bytes1 = tuple_to_bytes(tup1)
    dut.data_array.value = pack_array(bytes1, 10)
    dut.target.value = ord('r')  # 0x72
    dut.valid_count.value = 10
    await Timer(10, units='ns')
    assert dut.found.value == 1, f"Test 1 failed: expected 1, got {dut.found.value}"
    
    # Test 2: Search for '5' (0x35) in same tuple
    # Expected: False (does not exist)
    dut._log.info("Test 2: Searching for '5' (0x35)")
    dut.target.value = ord('5')  # 0x35
    await Timer(10, units='ns')
    assert dut.found.value == 0, f"Test 2 failed: expected 0, got {dut.found.value}"
    
    # Test 3: Search for number 3 (0x03) in same tuple
    # Expected: True (exists at position 1)
    dut._log.info("Test 3: Searching for 3 (0x03)")
    dut.target.value = 3  # 0x03
    await Timer(10, units='ns')
    assert dut.found.value == 1, f"Test 3 failed: expected 1, got {dut.found.value}"
    
    # Test 4: Edge case - search in single-element tuple
    dut._log.info("Test 4: Single element tuple")
    dut.data_array.value = ord('a')  # Only first byte is 'a'
    dut.target.value = ord('a')
    dut.valid_count.value = 1
    await Timer(10, units='ns')
    assert dut.found.value == 1, f"Test 4 failed: expected 1, got {dut.found.value}"
    
    # Test 5: Edge case - search for element not in first valid_count positions
    dut._log.info("Test 5: Target beyond valid count")
    bytes5 = tuple_to_bytes(("x", "y", "z", "a", "b", "c", "d", "e", "f", "g"))
    dut.data_array.value = pack_array(bytes5, 10)
    dut.target.value = ord('g')  # exists at position 9
    dut.valid_count.value = 3  # Only first 3 are valid
    await Timer(10, units='ns')
    assert dut.found.value == 0, f"Test 5 failed: expected 0 (g beyond valid count), got {dut.found.value}"
    
    # Test 6: Search for zero value
    dut._log.info("Test 6: Searching for zero")
    bytes6 = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9]
    dut.data_array.value = pack_array(bytes6, 10)
    dut.target.value = 0
    dut.valid_count.value = 10
    await Timer(10, units='ns')
    assert dut.found.value == 1, f"Test 6 failed: expected 1, got {dut.found.value}"
    
    dut._log.info("All 6 tests passed!")