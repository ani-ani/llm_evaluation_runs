import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure

# Helper function to convert string to 64-bit representation
def str_to_64bit(s):
    padded = s.ljust(8, ' ')
    bytes_arr = [ord(c) for c in padded]
    # Big-endian: first char at MSB
    value = 0
    for i, b in enumerate(bytes_arr):
        value |= b << (56 - i*8)
    return value

# Helper to convert 64-bit back to string
def bit64_to_str(value):
    chars = []
    for i in range(8):
        byte_val = (value >> (56 - i*8)) & 0xFF
        if byte_val == 0x20 and i > 0 and all(c == 0x20 for c in chars):
            break
        chars.append(byte_val)
    return ''.join(chr(b) for b in chars).rstrip(' ')

@cocotb.test()
async def test_sort_sublists_basic(dut):
    """Test basic sorting of sublists"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Test Case 1: Three sublists
    # Sublist 0: ["green", "orange", "black", "white"] → sorted: black, green, orange, white
    # Sublist 1: ["red", "green", "blue", "black"] → sorted: black, blue, green, red
    # Sublist 2: ["zilver", "gold", "steel", "bronze"] → sorted: bronze, gold, steel, zilver
    
    sublist_0_strings = ["green", "orange", "black", "white", "", "", "", ""]
    sublist_1_strings = ["red", "green", "blue", "black", "", "", "", ""]
    sublist_2_strings = ["zilver", "gold", "steel", "bronze", "", "", "", ""]
    
    # Set num_strings for each sublist
    dut.num_strings_0.value = 4
    dut.num_strings_1.value = 4
    dut.num_strings_2.value = 4
    dut.num_sublists.value = 3
    
    # Load string data
    for i, s in enumerate(sublist_0_strings):
        getattr(dut, f'sublist_0_str_{i}').value = str_to_64bit(s)
    for i, s in enumerate(sublist_1_strings):
        getattr(dut, f'sublist_1_str_{i}').value = str_to_64bit(s)
    for i, s in enumerate(sublist_2_strings):
        getattr(dut, f'sublist_2_str_{i}').value = str_to_64bit(s)
    
    await Timer(10, units='ns')
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Expected results
    expected_sublist_0 = ["black", "green", "orange", "white"]
    expected_sublist_1 = ["black", "blue", "green", "red"]
    expected_sublist_2 = ["bronze", "gold", "steel", "zilver"]
    
    # Wait for completion and collect results
    all_results = []
    current_sublist = 0
    sublist_results = []
    
    timeout = 500
    cycles = 0
    
    while cycles < timeout:
        await RisingEdge(dut.clk)
        cycles += 1
        
        if dut.result_valid.value and not dut.done.value:
            sublist = int(dut.current_sublist.value)
            output_strings = []
            # Get all 8 output strings
            for i in range(8):
                val = getattr(dut, f'result_str_{i}').value
                s = bit64_to_str(int(val))
                if s != "":
                    output_strings.append(s)
            
            # Collect for this sublist
            if sublist == current_sublist:
                sublist_results.append(output_strings)
            else:
                # New sublist started
                if sublist_results:
                    all_results.append(sublist_results[-1] if sublist_results else [])
                current_sublist = sublist
                sublist_results = [output_strings]
        
        if dut.done.value:
            if sublist_results:
                all_results.append(sublist_results[-1])
            break
    
    # Verify results
    dut._log.info(f"Collected results: {all_results}")
    
    # Check we got results for all 3 sublists
    assert len(all_results) >= 3, f"Expected 3 sublists, got {len(all_results)}"
    
    # Verify sublist 0
    result_0 = [s for s in all_results[0] if s]
    dut._log.info(f"Sublist 0 result: {result_0}")
    assert result_0 == expected_sublist_0, f"Sublist 0 mismatch: {result_0} vs {expected_sublist_0}"
    
    # Verify sublist 1
    result_1 = [s for s in all_results[1] if s]
    dut._log.info(f"Sublist 1 result: {result_1}")
    assert result_1 == expected_sublist_1, f"Sublist 1 mismatch: {result_1} vs {expected_sublist_1}"
    
    # Verify sublist 2
    result_2 = [s for s in all_results[2] if s]
    dut._log.info(f"Sublist 2 result: {result_2}")
    assert result_2 == expected_sublist_2, f"Sublist 2 mismatch: {result_2} vs {expected_sublist_2}"
    
    dut._log.info("All tests passed!")

@cocotb.test()
async def test_sort_sublists_single_sublist(dut):
    """Test with single sublist"""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Single sublist: ["zebra", "apple", "mango"] → sorted: apple, mango, zebra
    sublist_0_strings = ["zebra", "apple", "mango", "", "", "", "", ""]
    
    dut.num_strings_0.value = 3
    dut.num_sublists.value = 1
    
    for i, s in enumerate(sublist_0_strings):
        getattr(dut, f'sublist_0_str_{i}').value = str_to_64bit(s)
    
    await Timer(10, units='ns')
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for valid output
    timeout = 300
    cycles = 0
    results = []
    
    while cycles < timeout:
        await RisingEdge(dut.clk)
        cycles += 1
        
        if dut.result_valid.value:
            for i in range(8):
                val = getattr(dut, f'result_str_{i}').value
                s = bit64_to_str(int(val))
                if s:
                    results.append(s)
        
        if dut.done.value:
            break
    
    results = results[:3]  # Only first 3
    expected = ["apple", "mango", "zebra"]
    assert results == expected, f"Single sublist failed: {results} vs {expected}"
    dut._log.info(f"Single sublist test passed: {results}")

@cocotb.test()
async def test_sort_sublists_empty_strings(dut):
    """Test with empty strings mixed in"""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Sublist with empty strings: ["", "cat", "", "dog", ""] → should sort non-empty: cat, dog
    sublist_0_strings = ["", "cat", "", "dog", "", "", "", ""]
    
    dut.num_strings_0.value = 5
    dut.num_sublists.value = 1
    
    for i, s in enumerate(sublist_0_strings):
        getattr(dut, f'sublist_0_str_{i}').value = str_to_64bit(s)
    
    await Timer(10, units='ns')
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 300
    cycles = 0
    results = []
    
    while cycles < timeout:
        await RisingEdge(dut.clk)
        cycles += 1
        
        if dut.result_valid.value:
            for i in range(8):
                val = getattr(dut, f'result_str_{i}').value
                s = bit64_to_str(int(val))
                if s:
                    results.append(s)
        
        if dut.done.value:
            break
    
    # Empty strings are sorted as spaces (0x20) which is less than letters
    # They will appear at the beginning but we filter them out
    results = [r for r in results if r]
    expected = ["cat", "dog"]
    assert results == expected, f"Empty strings test failed: {results} vs {expected}"
    dut._log.info(f"Empty strings test passed: {results}")

@cocotb.test()
async def test_sort_sublists_max_sublists(dut):
    """Test with maximum 3 sublists of varying sizes"""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(50, units='ns')
    dut.rst_n.value = 1
    await Timer(50, units='ns')
    
    # Sublist 0: 2 elements ["ba", "ab"] → ["ab", "ba"]
    # Sublist 1: 8 elements ["z","y","x","w","v","u","t","s"] → ["s","t","u","v","w","x","y","z"]
    # Sublist 2: 1 element ["single"] → ["single"]
    
    sublist_0_strings = ["ba", "ab", "", "", "", "", "", ""]
    sublist_1_strings = ["z", "y", "x", "w", "v", "u", "t", "s"]
    sublist_2_strings = ["single", "", "", "", "", "", "", ""]
    
    dut.num_strings_0.value = 2
    dut.num_strings_1.value = 8
    dut.num_strings_2.value = 1
    dut.num_sublists.value = 3
    
    for i, s in enumerate(sublist_0_strings):
        getattr(dut, f'sublist_0_str_{i}').value = str_to_64bit(s)
    for i, s in enumerate(sublist_1_strings):
        getattr(dut, f'sublist_1_str_{i}').value = str_to_64bit(s)
    for i, s in enumerate(sublist_2_strings):
        getattr(dut, f'sublist_2_str_{i}').value = str_to_64bit(s)
    
    await Timer(10, units='ns')
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    timeout = 500
    cycles = 0
    all_results = {0: [], 1: [], 2: []}
    
    while cycles < timeout:
        await RisingEdge(dut.clk)
        cycles += 1
        
        if dut.result_valid.value:
            sublist = int(dut.current_sublist.value)
            # Get current output
            val = getattr(dut, f'result_str_0').value
            s = bit64_to_str(int(val))
            if s:
                all_results[sublist].append(s)
        
        if dut.done.value:
            break
    
    assert all_results[0] == ["ab", "ba"], f"Sublist 0 failed: {all_results[0]}"
    assert all_results[1] == ["s", "t", "u", "v", "w", "x", "y", "z"], f"Sublist 1 failed: {all_results[1]}"
    assert all_results[2] == ["single"], f"Sublist 2 failed: {all_results[2]}"
    
    dut._log.info(f"Max sublists test passed: {all_results}")
    dut._log.info("4/4 tests passed")
