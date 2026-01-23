import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure, TestSuccess

# Helper function to check if value is defined
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

# Helper function to wait for done signal with timeout
async def wait_for_done(dut, timeout_cycles=20):
    """Wait for done signal to go high, with cycle-based timeout."""
    for cycle in range(timeout_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            return cycle
    raise TestFailure(f"Timeout: done not asserted after {timeout_cycles} cycles")

# Helper to convert string to ASCII list
def str_to_ascii(s, max_len=8):
    """Convert string to list of ASCII values, padded to max_len with 0."""
    ascii_list = [ord(c) for c in s]
    # Pad with zeros to reach max_len
    ascii_list.extend([0] * (max_len - len(ascii_list)))
    return ascii_list[:max_len]

# Helper to read result array from dut
def read_result_array(dut, result_len):
    """Read result array from dut and convert to string."""
    result_chars = []
    for i in range(min(result_len, 8)):  # Safety limit
        if is_value_defined(dut.result[i].value):
            val = int(dut.result[i].value)
            if val != 0:
                result_chars.append(chr(val))
    return ''.join(result_chars)

# Helper to set input arrays
def set_input_array(dut, array_name, values):
    """Set values for input array."""
    for i, val in enumerate(values):
        getattr(dut, array_name)[i].value = val

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_reverse_delete_basic(dut):
    """Test basic reverse_delete functionality."""
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for i in range(8):
        dut.s[i].value = 0
        dut.c[i].value = 0
        dut.result[i].value = 0
    dut.s_len.value = 0
    dut.c_len.value = 0
    await Timer(50, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: s="abcde", c="ae" -> result="bcd", palindrome=False
    dut._log.info("Test 1: s='abcde', c='ae'")
    set_input_array(dut, 's', str_to_ascii("abcde"))
    set_input_array(dut, 'c', str_to_ascii("ae"))
    dut.s_len.value = 5
    dut.c_len.value = 2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    if not is_value_defined(dut.result_len.value):
        raise TestFailure("Test 1: result_len is undefined")
    if not is_value_defined(dut.palindrome.value):
        raise TestFailure("Test 1: palindrome is undefined")
    
    result_len = int(dut.result_len.value)
    palindrome = int(dut.palindrome.value)
    result_str = read_result_array(dut, result_len)
    
    dut._log.info(f"Test 1: result='{result_str}', len={result_len}, palindrome={palindrome}")
    
    if result_str != "bcd":
        raise TestFailure(f"Test 1: expected 'bcd', got '{result_str}'")
    if result_len != 3:
        raise TestFailure(f"Test 1: expected length 3, got {result_len}")
    if palindrome != 0:
        raise TestFailure(f"Test 1: expected palindrome=0, got {palindrome}")
    
    dut._log.info("Test 1 passed")

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_reverse_delete_palindrome(dut):
    """Test palindrome detection."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for i in range(8):
        dut.s[i].value = 0
        dut.c[i].value = 0
    dut.s_len.value = 0
    dut.c_len.value = 0
    await Timer(50, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 2: s="abcdedcba", c="ab" -> result="cdedc", palindrome=True
    dut._log.info("Test 2: s='abcdedcba', c='ab'")
    set_input_array(dut, 's', str_to_ascii("abcdedcba"))
    set_input_array(dut, 'c', str_to_ascii("ab"))
    dut.s_len.value = 9
    dut.c_len.value = 2
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    if not is_value_defined(dut.result_len.value):
        raise TestFailure("Test 2: result_len is undefined")
    if not is_value_defined(dut.palindrome.value):
        raise TestFailure("Test 2: palindrome is undefined")
    
    result_len = int(dut.result_len.value)
    palindrome = int(dut.palindrome.value)
    result_str = read_result_array(dut, result_len)
    
    dut._log.info(f"Test 2: result='{result_str}', len={result_len}, palindrome={palindrome}")
    
    if result_str != "cdedc":
        raise TestFailure(f"Test 2: expected 'cdedc', got '{result_str}'")
    if palindrome != 1:
        raise TestFailure(f"Test 2: expected palindrome=1, got {palindrome}")
    
    dut._log.info("Test 2 passed")

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_reverse_delete_empty_result(dut):
    """Test when all characters are deleted."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for i in range(8):
        dut.s[i].value = 0
        dut.c[i].value = 0
    dut.s_len.value = 0
    dut.c_len.value = 0
    await Timer(50, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 3: s="mamma", c="mia" -> result="", palindrome=True
    dut._log.info("Test 3: s='mamma', c='mia'")
    set_input_array(dut, 's', str_to_ascii("mamma"))
    set_input_array(dut, 'c', str_to_ascii("mia"))
    dut.s_len.value = 5
    dut.c_len.value = 3
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    if not is_value_defined(dut.result_len.value):
        raise TestFailure("Test 3: result_len is undefined")
    if not is_value_defined(dut.palindrome.value):
        raise TestFailure("Test 3: palindrome is undefined")
    
    result_len = int(dut.result_len.value)
    palindrome = int(dut.palindrome.value)
    result_str = read_result_array(dut, result_len)
    
    dut._log.info(f"Test 3: result='{result_str}', len={result_len}, palindrome={palindrome}")
    
    if result_str != "":
        raise TestFailure(f"Test 3: expected '', got '{result_str}'")
    if result_len != 0:
        raise TestFailure(f"Test 3: expected length 0, got {result_len}")
    if palindrome != 1:
        raise TestFailure(f"Test 3: expected palindrome=1, got {palindrome}")
    
    dut._log.info("Test 3 passed")

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_reverse_delete_no_deletion(dut):
    """Test when no characters match."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for i in range(8):
        dut.s[i].value = 0
        dut.c[i].value = 0
    dut.s_len.value = 0
    dut.c_len.value = 0
    await Timer(50, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 4: s="abcdedcba", c="v" -> result="abcdedcba", palindrome=True
    dut._log.info("Test 4: s='abcdedcba', c='v'")
    set_input_array(dut, 's', str_to_ascii("abcdedcba"))
    set_input_array(dut, 'c', str_to_ascii("v"))
    dut.s_len.value = 9
    dut.c_len.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    if not is_value_defined(dut.result_len.value):
        raise TestFailure("Test 4: result_len is undefined")
    if not is_value_defined(dut.palindrome.value):
        raise TestFailure("Test 4: palindrome is undefined")
    
    result_len = int(dut.result_len.value)
    palindrome = int(dut.palindrome.value)
    result_str = read_result_array(dut, result_len)
    
    dut._log.info(f"Test 4: result='{result_str}', len={result_len}, palindrome={palindrome}")
    
    if result_str != "abcdedcba":
        raise TestFailure(f"Test 4: expected 'abcdedcba', got '{result_str}'")
    if result_len != 9:
        raise TestFailure(f"Test 4: expected length 9, got {result_len}")
    if palindrome != 1:
        raise TestFailure(f"Test 4: expected palindrome=1, got {palindrome}")
    
    dut._log.info("Test 4 passed")

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_reverse_delete_single_char(dut):
    """Test single character string."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for i in range(8):
        dut.s[i].value = 0
        dut.c[i].value = 0
    dut.s_len.value = 0
    dut.c_len.value = 0
    await Timer(50, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 5: s="a", c="a" -> result="", palindrome=True
    dut._log.info("Test 5: s='a', c='a'")
    set_input_array(dut, 's', str_to_ascii("a"))
    set_input_array(dut, 'c', str_to_ascii("a"))
    dut.s_len.value = 1
    dut.c_len.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    if not is_value_defined(dut.result_len.value):
        raise TestFailure("Test 5: result_len is undefined")
    if not is_value_defined(dut.palindrome.value):
        raise TestFailure("Test 5: palindrome is undefined")
    
    result_len = int(dut.result_len.value)
    palindrome = int(dut.palindrome.value)
    result_str = read_result_array(dut, result_len)
    
    dut._log.info(f"Test 5: result='{result_str}', len={result_len}, palindrome={palindrome}")
    
    if result_str != "":
        raise TestFailure(f"Test 5: expected '', got '{result_str}'")
    if result_len != 0:
        raise TestFailure(f"Test 5: expected length 0, got {result_len}")
    if palindrome != 1:
        raise TestFailure(f"Test 5: expected palindrome=1, got {palindrome}")
    
    dut._log.info("Test 5 passed")

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_reverse_delete_vabba(dut):
    """Test vabba with v removed."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for i in range(8):
        dut.s[i].value = 0
        dut.c[i].value = 0
    dut.s_len.value = 0
    dut.c_len.value = 0
    await Timer(50, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 6: s="vabba", c="v" -> result="abba", palindrome=True
    dut._log.info("Test 6: s='vabba', c='v'")
    set_input_array(dut, 's', str_to_ascii("vabba"))
    set_input_array(dut, 'c', str_to_ascii("v"))
    dut.s_len.value = 5
    dut.c_len.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    if not is_value_defined(dut.result_len.value):
        raise TestFailure("Test 6: result_len is undefined")
    if not is_value_defined(dut.palindrome.value):
        raise TestFailure("Test 6: palindrome is undefined")
    
    result_len = int(dut.result_len.value)
    palindrome = int(dut.palindrome.value)
    result_str = read_result_array(dut, result_len)
    
    dut._log.info(f"Test 6: result='{result_str}', len={result_len}, palindrome={palindrome}")
    
    if result_str != "abba":
        raise TestFailure(f"Test 6: expected 'abba', got '{result_str}'")
    if result_len != 4:
        raise TestFailure(f"Test 6: expected length 4, got {result_len}")
    if palindrome != 1:
        raise TestFailure(f"Test 6: expected palindrome=1, got {palindrome}")
    
    dut._log.info("Test 6 passed")

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_reverse_delete_wik(dut):
    """Test dwik with w removed."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for i in range(8):
        dut.s[i].value = 0
        dut.c[i].value = 0
    dut.s_len.value = 0
    dut.c_len.value = 0
    await Timer(50, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 7: s="dwik", c="w" -> result="dik", palindrome=False
    dut._log.info("Test 7: s='dwik', c='w'")
    set_input_array(dut, 's', str_to_ascii("dwik"))
    set_input_array(dut, 'c', str_to_ascii("w"))
    dut.s_len.value = 4
    dut.c_len.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    if not is_value_defined(dut.result_len.value):
        raise TestFailure("Test 7: result_len is undefined")
    if not is_value_defined(dut.palindrome.value):
        raise TestFailure("Test 7: palindrome is undefined")
    
    result_len = int(dut.result_len.value)
    palindrome = int(dut.palindrome.value)
    result_str = read_result_array(dut, result_len)
    
    dut._log.info(f"Test 7: result='{result_str}', len={result_len}, palindrome={palindrome}")
    
    if result_str != "dik":
        raise TestFailure(f"Test 7: expected 'dik', got '{result_str}'")
    if result_len != 3:
        raise TestFailure(f"Test 7: expected length 3, got {result_len}")
    if palindrome != 0:
        raise TestFailure(f"Test 7: expected palindrome=0, got {palindrome}")
    
    dut._log.info("Test 7 passed")

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_reverse_delete_abcdef(dut):
    """Test abcdef with b removed."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for i in range(8):
        dut.s[i].value = 0
        dut.c[i].value = 0
    dut.s_len.value = 0
    dut.c_len.value = 0
    await Timer(50, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 8: s="abcdef", c="b" -> result="acdef", palindrome=False
    dut._log.info("Test 8: s='abcdef', c='b'")
    set_input_array(dut, 's', str_to_ascii("abcdef"))
    set_input_array(dut, 'c', str_to_ascii("b"))
    dut.s_len.value = 6
    dut.c_len.value = 1
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    if not is_value_defined(dut.result_len.value):
        raise TestFailure("Test 8: result_len is undefined")
    if not is_value_defined(dut.palindrome.value):
        raise TestFailure("Test 8: palindrome is undefined")
    
    result_len = int(dut.result_len.value)
    palindrome = int(dut.palindrome.value)
    result_str = read_result_array(dut, result_len)
    
    dut._log.info(f"Test 8: result='{result_str}', len={result_len}, palindrome={palindrome}")
    
    if result_str != "acdef":
        raise TestFailure(f"Test 8: expected 'acdef', got '{result_str}'")
    if result_len != 5:
        raise TestFailure(f"Test 8: expected length 5, got {result_len}")
    if palindrome != 0:
        raise TestFailure(f"Test 8: expected palindrome=0, got {palindrome}")
    
    dut._log.info("Test 8 passed")

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_reverse_delete_empty_c(dut):
    """Test with empty c string."""
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for i in range(8):
        dut.s[i].value = 0
        dut.c[i].value = 0
    dut.s_len.value = 0
    dut.c_len.value = 0
    await Timer(50, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 9: s="abcdedcba", c="" -> result="abcdedcba", palindrome=True
    dut._log.info("Test 9: s='abcdedcba', c=''")
    set_input_array(dut, 's', str_to_ascii("abcdedcba"))
    set_input_array(dut, 'c', str_to_ascii(""))
    dut.s_len.value = 9
    dut.c_len.value = 0
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    if not is_value_defined(dut.result_len.value):
        raise TestFailure("Test 9: result_len is undefined")
    if not is_value_defined(dut.palindrome.value):
        raise TestFailure("Test 9: palindrome is undefined")
    
    result_len = int(dut.result_len.value)
    palindrome = int(dut.palindrome.value)
    result_str = read_result_array(dut, result_len)
    
    dut._log.info(f"Test 9: result='{result_str}', len={result_len}, palindrome={palindrome}")
    
    if result_str != "abcdedcba":
        raise TestFailure(f"Test 9: expected 'abcdedcba', got '{result_str}'")
    if result_len != 9:
        raise TestFailure(f"Test 9: expected length 9, got {result_len}")
    if palindrome != 1:
        raise TestFailure(f"Test 9: expected palindrome=1, got {palindrome}")
    
    dut._log.info("Test 9 passed")

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_summary(dut):
    """Report test summary."""
    dut._log.info("=" * 50)
    dut._log.info("All 9 test cases completed successfully")
    dut._log.info("Module reverse_delete verified correctly")
    dut._log.info("=" * 50)
