import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure


def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False


def to_ascii_array(s, width=8):
    """Convert string to list of ASCII values, pad with spaces."""
    ascii_vals = [ord(c) for c in s[:width]]
    ascii_vals += [32] * (width - len(ascii_vals))  # Space padding
    return ascii_vals


def pack_string_to_int(ascii_list):
    """Pack list of 8 ASCII values into a 64-bit integer (little-endian)."""
    result = 0
    for i, val in enumerate(ascii_list):
        result |= (val & 0xFF) << (i * 8)
    return result


def pack_array_of_strings(strings):
    """Pack array of 8 strings into a list of 64-bit integers."""
    packed = []
    for s in strings:
        ascii_list = to_ascii_array(s, 8)
        packed.append(pack_string_to_int(ascii_list))
    return packed


def pack_prefix(prefix_str, length):
    """Pack prefix into an array of 8 bytes."""
    ascii_list = to_ascii_array(prefix_str, 8)
    return ascii_list


@cocotb.test(timeout_time=500, timeout_unit='ms')
async def test_filter_by_prefix_basic(dut):
    """Test basic prefix filtering."""
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: filter_by_prefix(['abc', 'bcd', 'cde', 'array'], 'a') -> ['abc', 'array']
    dut._log.info("Test 1: Filter strings by prefix 'a'")
    
    # Prepare inputs
    input_strings = ['abc', 'bcd', 'cde', 'array']
    num_strings = 4
    prefix = 'a'
    prefix_len = 1
    
    # Pack strings into individual bytes (access as 2D array)
    packed_strings = pack_array_of_strings(input_strings)
    
    # Assign to dut.strings[i] - individual elements
    for i, packed_val in enumerate(packed_strings):
        # Need to assign byte by byte since it's a 2D array
        ascii_vals = to_ascii_array(input_strings[i])
        for j, byte_val in enumerate(ascii_vals):
            dut.strings[i][j].value = byte_val
    
    # Assign prefix
    prefix_ascii = to_ascii_array(prefix)
    for i, byte_val in enumerate(prefix_ascii):
        dut.prefix[i].value = byte_val
    
    dut.num_strings.value = num_strings
    dut.prefix_len.value = prefix_len
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done with timeout
    max_cycles = 100
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            break
    else:
        raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")
    
    # Check result_count
    if not is_value_defined(dut.result_count.value):
        raise TestFailure("result_count is undefined (X/Z)")
    
    result_count = int(dut.result_count.value)
    dut._log.info(f"Result count: {result_count}")
    
    if result_count != 2:
        raise TestFailure(f"Expected result_count=2, got {result_count}")
    
    # Check matching strings
    # Results should contain 'abc' and 'array'
    expected_strings = {'abc', 'array'}
    found_strings = set()
    
    for i in range(result_count):
        # Read string from results array
        char_values = []
        for j in range(8):
            if is_value_defined(dut.results[i][j].value):
                char_val = int(dut.results[i][j].value)
                if char_val >= 32:  # Printable ASCII
                    char_values.append(chr(char_val))
        
        found_str = ''.join(char_values).rstrip()
        if found_str:
            found_strings.add(found_str)
            dut._log.info(f"Result {i}: '{found_str}'")
    
    if found_strings != expected_strings:
        raise TestFailure(f"Expected {expected_strings}, got {found_strings}")


@cocotb.test(timeout_time=500, timeout_unit='ms')
async def test_filter_by_prefix_multiple(dut):
    """Test with 'xxx' prefix filtering multiple matches."""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test: ['xxx', 'asd', 'xxy', 'john doe', 'xxxAAA', 'xxx'], 'xxx'
    input_strings = ['xxx', 'asd', 'xxy', 'john doe', 'xxxAAA', 'xxx']
    num_strings = 6
    prefix = 'xxx'
    prefix_len = 3
    
    # Assign strings
    for i, s in enumerate(input_strings):
        ascii_vals = to_ascii_array(s)
        for j, byte_val in enumerate(ascii_vals):
            dut.strings[i][j].value = byte_val
    
    # Assign prefix
    prefix_ascii = to_ascii_array(prefix)
    for i, byte_val in enumerate(prefix_ascii):
        dut.prefix[i].value = byte_val
    
    dut.num_strings.value = num_strings
    dut.prefix_len.value = prefix_len
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    max_cycles = 100
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            break
    else:
        raise TestFailure(f"Timeout after {max_cycles} cycles")
    
    # Check results
    result_count = int(dut.result_count.value)
    dut._log.info(f"Result count: {result_count}")
    
    if result_count != 3:
        raise TestFailure(f"Expected 3 matches, got {result_count}")
    
    # Expected: 'xxx', 'xxxAAA', 'xxx'
    expected_strings = {'xxx', 'xxxAAA'}
    found_strings = set()
    
    for i in range(result_count):
        char_values = []
        for j in range(8):
            if is_value_defined(dut.results[i][j].value):
                char_val = int(dut.results[i][j].value)
                if char_val >= 32:
                    char_values.append(chr(char_val))
        
        found_str = ''.join(char_values).rstrip()
        if found_str:
            found_strings.add(found_str)
            dut._log.info(f"Result {i}: '{found_str}'")
    
    # The first 'xxx' and 'xxxAAA' should be in results
    if 'xxxAAA' not in found_strings:
        raise TestFailure(f"Missing 'xxxAAA' in results: {found_strings}")
    if 'xxx' not in found_strings:
        raise TestFailure(f"Missing 'xxx' in results: {found_strings}")


@cocotb.test(timeout_time=500, timeout_unit='ms')
async def test_filter_by_prefix_empty(dut):
    """Test with empty input list."""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Empty list
    num_strings = 0
    prefix = 'john'
    prefix_len = 4
    
    dut.num_strings.value = num_strings
    dut.prefix_len.value = prefix_len
    
    # Assign prefix
    prefix_ascii = to_ascii_array(prefix)
    for i, byte_val in enumerate(prefix_ascii):
        dut.prefix[i].value = byte_val
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    max_cycles = 100
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            break
    else:
        raise TestFailure(f"Timeout after {max_cycles} cycles")
    
    result_count = int(dut.result_count.value)
    dut._log.info(f"Result count for empty input: {result_count}")
    
    if result_count != 0:
        raise TestFailure(f"Expected result_count=0, got {result_count}")


@cocotb.test(timeout_time=500, timeout_unit='ms')
async def test_filter_by_prefix_no_match(dut):
    """Test when no strings match the prefix."""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # ['hello', 'world'] with prefix 'xyz'
    input_strings = ['hello', 'world']
    num_strings = 2
    prefix = 'xyz'
    prefix_len = 3
    
    # Assign strings
    for i, s in enumerate(input_strings):
        ascii_vals = to_ascii_array(s)
        for j, byte_val in enumerate(ascii_vals):
            dut.strings[i][j].value = byte_val
    
    # Assign prefix
    prefix_ascii = to_ascii_array(prefix)
    for i, byte_val in enumerate(prefix_ascii):
        dut.prefix[i].value = byte_val
    
    dut.num_strings.value = num_strings
    dut.prefix_len.value = prefix_len
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    max_cycles = 100
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            break
    else:
        raise TestFailure(f"Timeout after {max_cycles} cycles")
    
    result_count = int(dut.result_count.value)
    dut._log.info(f"Result count for no match: {result_count}")
    
    if result_count != 0:
        raise TestFailure(f"Expected result_count=0, got {result_count}")


@cocotb.test(timeout_time=500, timeout_unit='ms')
async def test_filter_by_prefix_partial_string(dut):
    """Test prefix that is substring of longer string."""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # ['cat', 'caterpillar', 'dog', 'cow'], prefix 'ca'
    input_strings = ['cat', 'caterpillar', 'dog', 'cow']
    num_strings = 4
    prefix = 'ca'
    prefix_len = 2
    
    # Assign strings
    for i, s in enumerate(input_strings):
        ascii_vals = to_ascii_array(s)
        for j, byte_val in enumerate(ascii_vals):
            dut.strings[i][j].value = byte_val
    
    # Assign prefix
    prefix_ascii = to_ascii_array(prefix)
    for i, byte_val in enumerate(prefix_ascii):
        dut.prefix[i].value = byte_val
    
    dut.num_strings.value = num_strings
    dut.prefix_len.value = prefix_len
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    max_cycles = 100
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            break
    else:
        raise TestFailure(f"Timeout after {max_cycles} cycles")
    
    result_count = int(dut.result_count.value)
    dut._log.info(f"Result count: {result_count}")
    
    if result_count != 2:
        raise TestFailure(f"Expected result_count=2, got {result_count}")
    
    # Check for 'cat' and 'caterpillar'
    expected = {'cat', 'caterpillar'}
    found = set()
    
    for i in range(result_count):
        char_values = []
        for j in range(8):
            if is_value_defined(dut.results[i][j].value):
                char_val = int(dut.results[i][j].value)
                if char_val >= 32:
                    char_values.append(chr(char_val))
        
        found_str = ''.join(char_values).rstrip()
        if found_str:
            found_strings.add(found_str)
            dut._log.info(f"Result {i}: '{found_str}'")
    
    if found != expected:
        raise TestFailure(f"Expected {expected}, got {found}")


@cocotb.test(timeout_time=500, timeout_unit='ms')
async def test_filter_by_prefix_max_width(dut):
    """Test with 8-character strings at maximum width."""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Full width strings
    input_strings = ['abcdefgh', 'abcdefgg', 'abcde', 'xyzw']
    num_strings = 4
    prefix = 'abcdefg'
    prefix_len = 7
    
    # Assign strings
    for i, s in enumerate(input_strings):
        ascii_vals = to_ascii_array(s)
        for j, byte_val in enumerate(ascii_vals):
            dut.strings[i][j].value = byte_val
    
    # Assign prefix
    prefix_ascii = to_ascii_array(prefix)
    for i, byte_val in enumerate(prefix_ascii):
        dut.prefix[i].value = byte_val
    
    dut.num_strings.value = num_strings
    dut.prefix_len.value = prefix_len
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    max_cycles = 100
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            break
    else:
        raise TestFailure(f"Timeout after {max_cycles} cycles")
    
    result_count = int(dut.result_count.value)
    dut._log.info(f"Result count: {result_count}")
    
    if result_count != 2:
        raise TestFailure(f"Expected 2 matches, got {result_count}")
    
    # Should match 'abcdefgh' and 'abcdefgg'
    expected = {'abcdefgh', 'abcdefgg'}
    found = set()
    
    for i in range(result_count):
        char_values = []
        for j in range(8):
            if is_value_defined(dut.results[i][j].value):
                char_val = int(dut.results[i][j].value)
                if char_val >= 32:
                    char_values.append(chr(char_val))
        
        found_str = ''.join(char_values).rstrip()
        if found_str:
            found.add(found_str)
            dut._log.info(f"Result {i}: '{found_str}'")
    
    if found != expected:
        raise TestFailure(f"Expected {expected}, got {found}")


@cocotb.test(timeout_time=500, timeout_unit='ms')
async def test_filter_by_prefix_empty_prefix(dut):
    """Test with empty prefix - should return all strings."""
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    input_strings = ['apple', 'banana', 'cherry']
    num_strings = 3
    prefix = ''
    prefix_len = 0
    
    # Assign strings
    for i, s in enumerate(input_strings):
        ascii_vals = to_ascii_array(s)
        for j, byte_val in enumerate(ascii_vals):
            dut.strings[i][j].value = byte_val
    
    # Prefix length 0 - no need to assign prefix
    dut.num_strings.value = num_strings
    dut.prefix_len.value = prefix_len
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    max_cycles = 100
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            break
    else:
        raise TestFailure(f"Timeout after {max_cycles} cycles")
    
    result_count = int(dut.result_count.value)
    dut._log.info(f"Result count with empty prefix: {result_count}")
    
    # With empty prefix, all strings should match
    if result_count != num_strings:
        raise TestFailure(f"Expected {num_strings} matches, got {result_count}")