import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
KEY_WIDTH = 8
COUNT_WIDTH = 8
MAX_UNIQUE = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 5000

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

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

# ============================================================================
# TESTBENCH
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_freq_count(dut):
    """Test frequency counting with streaming input/output."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.valid_in.value = 0
    dut.done_in.value = 0
    dut.data_in.value = 0
    
    for _ in range(3):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Define test cases
    test_cases = [
        ([10,10,10,10,20,20,20,20,40,40,50,50,30], {10: 4, 20: 4, 40: 2, 50: 2, 30: 1}),
        ([1,2,3,4,3,2,4,1,3,1,4], {1: 3, 2: 2, 3: 3, 4: 3}),
        ([5,6,7,4,9,10,4,5,6,7,9,5], {5: 3, 6: 2, 7: 2, 4: 2, 9: 2, 10: 1}),
    ]
    
    for test_idx, (input_list, expected_dict) in enumerate(test_cases):
        dut._log.info(f"\nTest {test_idx + 1}: Input {input_list}")
        
        # Start pulse
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Feed input elements
        for val in input_list:
            dut.data_in.value = clamp_to_width(val, DATA_WIDTH)
            dut.valid_in.value = 1
            await RisingEdge(dut.clk)
        
        # Signal end of input
        dut.valid_in.value = 0
        dut.done_in.value = 1
        await RisingEdge(dut.clk)
        dut.done_in.value = 0
        
        # Collect output
        results = {}
        timeout = 1000
        cycles = 0
        
        while cycles < timeout:
            await RisingEdge(dut.clk)
            cycles += 1
            
            if is_value_defined(dut.valid_out.value) and int(dut.valid_out.value) == 1:
                key = int(dut.key_out.value)
                count = int(dut.count_out.value)
                if key in results:
                    raise TestFailure(f"Duplicate key {key} in output")
                results[key] = count
                dut._log.info(f"  Output: key={key}, count={count}")
            
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        else:
            raise TestFailure(f"Timeout waiting for done signal")
        
        # Verify results
        if results != expected_dict:
            raise TestFailure(f"Test {test_idx + 1} failed: expected {expected_dict}, got {results}")
        
        dut._log.info(f"  Test {test_idx + 1} PASSED")
        
        # Wait before next test
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    
    dut._log.info("="*50)
    dut._log.info("All tests passed")

# ============================================================================
# ALTERNATIVE TESTBENCH - SIMPLER COMBINATIONAL VERSION
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_freq_count_combinational(dut):
    """Alternative: Combinational block with sequential wrapper."""
    
    # This test assumes a simpler interface:
    # - Input: 8-element array, each 8-bit
    # - Output: Up to 8 pairs of (key, count) as individual ports
    
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    
    # Check for array interface
    has_arr = has_signal(dut, 'arr_0') or has_signal(dut, 'arr')
    
    if not has_arr:
        dut._log.info("No array interface found, skipping combinational test")
        return
    
    test_cases = [
        ([10,10,10,10,20,20,20,20], {10: 4, 20: 4}),
        ([1,2,3,4,3,2,4,1], {1: 2, 2: 2, 3: 2, 4: 2}),
    ]
    
    for test_idx, (input_list, expected_dict) in enumerate(test_cases):
        dut._log.info(f"\nCombinational Test {test_idx + 1}: {input_list}")
        
        # Pad to 8 elements
        padded = input_list + [0] * (8 - len(input_list))
        
        # Write to array
        for i in range(8):
            port_name = f'arr_{i}'
            if has_signal(dut, port_name):
                getattr(dut, port_name).value = clamp_to_width(padded[i], DATA_WIDTH)
            else:
                dut.arr[i].value = clamp_to_width(padded[i], DATA_WIDTH)
        
        # Wait for combinational propagation
        await Timer(100, units='ns')
        await RisingEdge(dut.clk)
        
        # Read results
        results = {}
        for i in range(8):
            key_sig = f'key_{i}' if has_signal(dut, f'key_{i}') else None
            count_sig = f'count_{i}' if has_signal(dut, f'count_{i}') else None
            
            if key_sig and count_sig:
                key = int(getattr(dut, key_sig).value)
                count = int(getattr(dut, count_sig).value)
                if count > 0 and key != 0:
                    results[key] = count
        
        # Verify
        if results != expected_dict:
            raise TestFailure(f"Expected {expected_dict}, got {results}")
        
        dut._log.info(f"  Combinational Test {test_idx + 1} PASSED")
    
    dut._log.info("All combinational tests passed")