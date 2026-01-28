import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
MAX_LEN = 16
DATA_WIDTH = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 100
ASCII_STAR = 42

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

async def write_array(dut, array_name, values, element_width):
    try:
        arr = getattr(dut, array_name)
        for i, val in enumerate(values):
            arr[i].value = clamp_to_width(val, element_width)
        return
    except (AttributeError, TypeError):
        pass
    
    for i, val in enumerate(values):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            raise TestFailure(f"Cannot find array port: {array_name}[{i}] or {port_name}")

async def read_array(dut, array_name, size):
    results = []
    try:
        arr = getattr(dut, array_name)
        for i in range(size):
            if is_value_defined(arr[i].value):
                results.append(int(arr[i].value))
            else:
                results.append(None)
        return results
    except (AttributeError, TypeError):
        pass
    
    for i in range(size):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            val = getattr(dut, port_name).value
            if is_value_defined(val):
                results.append(int(val))
            else:
                results.append(None)
        else:
            results.append(None)
    return results

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_string_match(dut):
    """Test string matching with wildcard"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    def str_to_ascii(s):
        return [ord(c) for c in s]
    
    # Test cases: (pattern, target, expected)
    test_cases = [
        ("code*s", "codeforces", True),
        ("vk*cup", "vkcup", True),
        ("v", "k", False),
        ("gfgf*gfgf", "gfgfgf", False),
        ("*", "anything", True),
        ("*", "", True),
        ("a", "a", True),
        ("ab", "a", False),
        ("ab*", "ab", True),
        ("ab*", "abc", True),
        ("*ab", "ab", True),
        ("*ab", "cab", True),
        ("a*b", "ab", True),
        ("a*b", "acb", True),
        ("a*b", "acdb", True),
        ("a*b", "acbc", False),
        ("a*b", "b", False),
        ("a*b", "a", False),
        ("aa*bb", "aaXXbb", True),
        ("aa*bb", "aaXXb", False),
        ("aa*bb", "aabb", True),
        ("aa*bb", "aaBBBBbb", True),
        ("aa*bb", "aaBBBBb", False),
        ("aa*bb", "aabbx", False),
        ("aa*bb", "aaxbb", False),
        ("aa*bb", "aa*bb", False),
        ("ab*cd*ef", "abcdef", False),
        ("", "", True),
        ("", "a", False),
        ("a", "", False),
    ]
    
    passed = 0
    failed = 0
    
    for i, (s_str, t_str, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: s='{s_str}' t='{t_str}' expected={'YES' if expected else 'NO'}")
        
        # Convert and pad
        s_ascii = str_to_ascii(s_str)
        t_ascii = str_to_ascii(t_str)
        s_arr = s_ascii + [0] * (MAX_LEN - len(s_ascii))
        t_arr = t_ascii + [0] * (MAX_LEN - len(t_ascii))
        n = len(s_ascii)
        m = len(t_ascii)
        
        try:
            # Write inputs
            await write_array(dut, 's_arr', s_arr, DATA_WIDTH)
            await write_array(dut, 't_arr', t_arr, DATA_WIDTH)
            dut.n.value = n
            dut.m.value = m
            
            # Execute
            await start_computation(dut)
            await wait_for_done(dut)
            
            # Verify
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = bool(int(dut.result.value))
            if result != expected:
                raise TestFailure(f"Expected {'YES' if expected else 'NO'}, got {'YES' if result else 'NO'}")
            
            cocotb.log.info(f"  PASS")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"Results: {passed}/{passed+failed} passed")
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
