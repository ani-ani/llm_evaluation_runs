import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
MAX_ELEMENTS = 12
CLK_PERIOD_NS = 10
MAX_CYCLES = 200

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def write_input_array(dut, values):
    """Write values to individual arr_0..arr_11 ports."""
    for i in range(MAX_ELEMENTS):
        port_name = f'arr_{i}'
        if has_signal(dut, port_name):
            if i < len(values):
                getattr(dut, port_name).value = clamp_to_width(values[i], DATA_WIDTH)
            else:
                getattr(dut, port_name).value = 0

async def read_output_pairs(dut, num_pairs):
    """Read output value-count pairs."""
    results = {}
    for i in range(min(num_pairs, MAX_ELEMENTS)):
        val_sig = f'out_val_{i}'
        count_sig = f'out_count_{i}'
        
        if has_signal(dut, val_sig) and has_signal(dut, count_sig):
            val = int(getattr(dut, val_sig).value)
            count = int(getattr(dut, count_sig).value)
            results[val] = count
    return results

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_frequency_lists(dut):
    """Test frequency counting of flattened list."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases
    test_cases = [
        # (input_list, expected_dict, description)
        ([1, 2, 3, 2, 4, 5, 6, 2, 7, 8, 9, 5], 
         {1: 1, 2: 3, 3: 1, 4: 1, 5: 2, 6: 1, 7: 1, 8: 1, 9: 1}, 
         "Test 1: Original test case flattened"),
        
        ([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12],
         {1: 1, 2: 1, 3: 1, 4: 1, 5: 1, 6: 1, 7: 1, 8: 1, 9: 1, 10: 1, 11: 1, 12: 1},
         "Test 2: All unique elements"),
        
        ([20, 30, 40, 17, 18, 16, 14, 13, 10, 20, 30, 40],
         {20: 2, 30: 2, 40: 2, 17: 1, 18: 1, 16: 1, 14: 1, 13: 1, 10: 1},
         "Test 3: With duplicates"),
        
        ([5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5],
         {5: 12},
         "Test 4: All same element"),
        
        ([1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6],
         {1: 2, 2: 2, 3: 2, 4: 2, 5: 2, 6: 2},
         "Test 5: Pairs"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_list, expected_dict, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {description}")
        cocotb.log.info(f"  Input: {input_list}")
        cocotb.log.info(f"  Expected: {expected_dict}")
        
        try:
            # Write inputs to individual ports
            for j in range(MAX_ELEMENTS):
                port_name = f'arr_{j}'
                if j < len(input_list):
                    val = clamp_to_width(input_list[j], DATA_WIDTH)
                    getattr(dut, port_name).value = val
                else:
                    getattr(dut, port_name).value = 0
            
            # Set num_elements
            dut.num_elements.value = len(input_list)
            
            # Wait a bit for inputs to settle
            await Timer(10, units='ns')
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read num_pairs first
            if not is_value_defined(dut.out_num_pairs.value):
                raise TestFailure("out_num_pairs is undefined")
            
            num_pairs = int(dut.out_num_pairs.value)
            cocotb.log.info(f"  Number of unique pairs: {num_pairs}")
            
            # Read output pairs
            results = {}
            for j in range(num_pairs):
                val_sig = f'out_val_{j}'
                count_sig = f'out_count_{j}'
                
                if not has_signal(dut, val_sig) or not has_signal(dut, count_sig):
                    raise TestFailure(f"Missing output signals for pair {j}")
                
                val = int(getattr(dut, val_sig).value)
                count = int(getattr(dut, count_sig).value)
                
                if val in results:
                    raise TestFailure(f"Duplicate value {val} in output pairs")
                
                results[val] = count
            
            cocotb.log.info(f"  Computed result: {results}")
            
            # Verify counts match expected
            if results != expected_dict:
                # Check if counts are correct (values might be in different order)
                if set(results.keys()) != set(expected_dict.keys()):
                    raise TestFailure(
                        f"Value mismatch. Expected keys {set(expected_dict.keys())}, "
                        f"got {set(results.keys())}"
                    )
                else:
                    # Keys match, check counts
                    for key in expected_dict:
                        if results[key] != expected_dict[key]:
                            raise TestFailure(
                                f"Count mismatch for value {key}: expected {expected_dict[key]}, got {results[key]}"
                            )
            
            cocotb.log.info(f"  Result: PASS")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  Result: FAIL - {e}")
            failed += 1
            # Reset for next test
            await reset_dut(dut)
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"SUMMARY: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
