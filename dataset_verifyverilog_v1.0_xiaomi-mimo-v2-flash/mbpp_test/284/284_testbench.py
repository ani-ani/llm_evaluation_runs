import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 50

# Helpers from A
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# ASCII conversion helpers
def ascii_to_int(s, length=ARRAY_SIZE):
    """Convert string to array of ASCII values, pad with spaces (0x20)"""
    if len(s) > length:
        raise ValueError(f"String too long: {len(s)} > {length}")
    result = [ord(c) for c in s]
    while len(result) < length:
        result.append(0x20)  # Space padding
    return result

def int_to_ascii(vals):
    """Convert ASCII values back to string"""
    return ''.join(chr(v) for v in vals if v != 0x20)

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_check_element(dut):
    # Setup clock if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational
        pass
    
    # Test cases
    test_cases = [
        # (description, array_data, target, expected_result)
        ("All match - integers", [1, 2, 3, 4, 5, 6, 7, 8], 5, False),  # Note: Not all match 5!
        ("All match - integers", [7, 7, 7, 7, 7, 7, 7, 7], 7, True),
        ("All match - ASCII", ascii_to_int("green") + [0x20, 0x20, 0x20], 0x67, False),  # 'g' is first
        ("All match - ASCII", ascii_to_int("green") + [0x20, 0x20, 0x20], 0x67, False),
        ("All match - ASCII", ascii_to_int("gggggggg"), 0x67, True),  # All 'g'
        ("No match - integers", [1, 2, 3, 4], 7, False),  # Different array length in test
        ("Partial match - ASCII", ascii_to_int("green") + [0x20, 0x20, 0x20], 0x67, False),  # 'g' at index 0 only
        ("All zeros", [0, 0, 0, 0, 0, 0, 0, 0], 0, True),
        ("Single mismatch", [1, 1, 1, 1, 1, 1, 1, 2], 1, False),
        ("All match - short", [9, 9, 9, 9, 0, 0, 0, 0], 9, False),  # Only first 4 match
    ]
    
    passed = 0
    failed = 0
    
    for i, (desc, arr_vals, target, expected) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {desc}")
        cocotb.log.info(f"  Array: {arr_vals}")
        cocotb.log.info(f"  Target: {target}")
        
        try:
            # Write array elements - CRITICAL: individual assignment
            # First check if array is indexed (arr[0], arr[1]...)
            # or if it's a single signal with bit indexing
            has_indexed = has_signal(dut, 'arr_0') or has_signal(dut, 'arr[0]')
            
            if has_indexed:
                for i in range(ARRAY_SIZE):
                    val = arr_vals[i] if i < len(arr_vals) else 0
                    try:
                        getattr(dut, f'arr_{i}').value = clamp_to_width(val, DATA_WIDTH)
                    except AttributeError:
                        # Try arr[i] syntax
                        dut.arr[i].value = clamp_to_width(val, DATA_WIDTH)
            else:
                # Single array port
                for i in range(min(ARRAY_SIZE, len(arr_vals))):
                    dut.arr[i].value = clamp_to_width(arr_vals[i], DATA_WIDTH)
                # Zero out remaining
                for i in range(len(arr_vals), ARRAY_SIZE):
                    dut.arr[i].value = 0
            
            # Write target
            if has_signal(dut, 'target'):
                dut.target.value = clamp_to_width(target, DATA_WIDTH)
            else:
                cocotb.log.warning("target signal not found, skipping")
                continue
            
            if is_seq:
                # Start operation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut)
                
                # Check result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result signal undefined")
                
                result = int(dut.result.value)
                
                # Validate
                if result != expected:
                    raise TestFailure(f"Expected {expected}, got {result}")
                
                # Ensure done is still 1-cycle
                await RisingEdge(dut.clk)
                if int(dut.done.value) == 1:
                    raise TestFailure("done signal not 1-cycle pulse")
            else:
                # Combinational - no start needed
                await Timer(100, units='ns')
                
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result signal undefined")
                
                result = int(dut.result.value)
                if result != expected:
                    raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result={result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"\n{failed} tests failed, {passed} passed")
    else:
        cocotb.log.info(f"\nAll {passed} tests passed!")
