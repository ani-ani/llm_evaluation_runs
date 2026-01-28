import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Array write helper
async def write_array(dut, name, vals, width=8, max_len=8):
    # Clamp values to width and pad with zeros
    padded_vals = [clamp_to_width(v, width) for v in vals] + [0] * (max_len - len(vals))
    # Write to array elements
    for i in range(max_len):
        try:
            dut.__getattr__(name)[i].value = padded_vals[i]
        except AttributeError:
            # Alternative naming convention
            attr_name = f"{name}_{i}"
            if has_signal(dut, attr_name):
                getattr(dut, attr_name).value = padded_vals[i]
            else:
                raise TestFailure(f"Cannot access {name} array element {i}")

# Set length signals
async def set_lengths(dut, len1, len2):
    dut.len1.value = clamp_to_width(len1, 4)
    dut.len2.value = clamp_to_width(len2, 4)

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_common_element(dut):
    """Test common element detection with various arrays."""
    
    # Setup clock if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
    
    # Test cases: (list1, list2, expected_result, description)
    # Note: String tests use ASCII byte values
    test_cases = [
        ([1,2,3,4,5], [5,6,7,8,9], True, "Integer arrays with common 5"),
        ([1,2,3,4,5], [6,7,8,9], False, "Integer arrays with no common"),
        ([ord('a'), ord('b'), ord('c')], [ord('d'), ord('b'), ord('e')], True, "Strings with common 'b'"),
        ([1,2,1,3], [2,3,4], True, "Arrays with duplicates"),
        ([], [1,2,3], False, "Empty first array"),
        ([1,2,3], [], False, "Empty second array"),
        ([], [], False, "Both empty arrays"),
        ([255, 0, 1], [255, 128, 64], True, "Edge values 8-bit"),
        ([8,7,6,5], [4,3,2,1], False, "Eight elements, no match"),
        ([8,7,6,5,4,3,2,1], [1,2,3,4,5,6,7,8], True, "Full 8-element arrays, match"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (list1, list2, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {desc}")
        cocotb.log.info(f"  list1={list1}, list2={list2}, expected={expected}")
        
        try:
            # Write arrays
            await write_array(dut, 'arr1', list1, 8, 8)
            await write_array(dut, 'arr2', list2, 8, 8)
            
            # Write lengths
            await set_lengths(dut, len(list1), len(list2))
            
            if is_seq:
                # Start computation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut)
                
                # Read result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result signal is undefined")
                
                result = int(dut.result.value)
                result_bool = bool(result)
                
                # Log result
                cocotb.log.info(f"  Result: {result_bool} (binary: {result})")
                
                # Check expected
                if result_bool != expected:
                    raise TestFailure(f"Expected {expected}, got {result_bool}")
                
                passed += 1
                cocotb.log.info(f"  PASS")
            else:
                # Combinational - just read after delay
                await Timer(100, units='ns')
                result = int(dut.result.value)
                result_bool = bool(result)
                
                if result_bool != expected:
                    raise TestFailure(f"Expected {expected}, got {result_bool}")
                
                passed += 1
                cocotb.log.info(f"  PASS")
                
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        except Exception as e:
            cocotb.log.error(f"  ERROR: {e}")
            failed += 1
    
    # Final results
    cocotb.log.info(f"\n=== Test Summary ===")
    cocotb.log.info(f"Passed: {passed}/{len(test_cases)}")
    cocotb.log.info(f"Failed: {failed}/{len(test_cases)}")
    
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_timing(dut):
    """Test that computation completes within 100 cycles."""
    
    if not has_signal(dut, 'clk'):
        cocotb.log.info("Skipping timing test for combinational module")
        return
    
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test worst case: 8 elements each, no match
    await write_array(dut, 'arr1', [1,2,3,4,5,6,7,8], 8, 8)
    await write_array(dut, 'arr2', [9,10,11,12,13,14,15,16], 8, 8)
    await set_lengths(dut, 8, 8)
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Measure cycles
    cycles = 0
    for _ in range(100):
        await RisingEdge(dut.clk)
        cycles += 1
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            cocotb.log.info(f"Completed in {cycles} cycles")
            if cycles > 100:
                raise TestFailure(f"Computation took {cycles} cycles, exceeds 100-cycle limit")
            return
    
    raise TestFailure("Did not complete within 100 cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_reset_behavior(dut):
    """Test reset clears state properly."""
    
    if not has_signal(dut, 'clk'):
        cocotb.log.info("Skipping reset test for combinational module")
        return
    
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut, cycles=5)
    
    # Check reset state
    if is_value_defined(dut.result.value) and int(dut.result.value) != 0:
        raise TestFailure(f"Result not 0 after reset: {dut.result.value}")
    
    if is_value_defined(dut.done.value) and int(dut.done.value) != 0:
        raise TestFailure(f"Done not 0 after reset: {dut.done.value}")
    
    cocotb.log.info("Reset behavior verified")
