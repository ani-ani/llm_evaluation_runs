import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.result import TestFailure, TestSuccess

# Helper function to check if value is defined (not X/Z)
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

# Helper to convert to signed from unsigned representation
def to_signed(val, bits=16):
    """Convert unsigned to signed representation."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

# Helper to convert signed to unsigned for assignment
def from_signed(val, bits=16):
    """Convert signed to unsigned for assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

@cocotb.test(timeout_time=500, timeout_unit="ms")
async def test_maximum_k(dut):
    """Test the maximum_k module with various test cases."""
    
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.k.value = 0
    dut.arr_len.value = 0
    for i in range(8):
        dut.arr[i].value = 0
    
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (arr_list, k, expected_list)
    test_cases = [
        ([-3, -4, 5], 3, [-4, -3, 5]),
        ([4, -4, 4], 2, [4, 4]),
        ([-3, 2, 1, 2, -1, -2, 1], 1, [2]),
        ([123, -123, 20, 0, 1, 2, -3], 3, [2, 20, 123]),
        ([-123, 20, 0, 1, 2, -3], 4, [0, 1, 2, 20]),
        ([5, 15, 0, 3, -13, -8, 0], 7, [-13, -8, 0, 0, 3, 5, 15]),
        ([-1, 0, 2, 5, 3, -10], 2, [3, 5]),
        ([1, 0, 5, -7], 1, [5]),
        ([4, -4], 2, [-4, 4]),
        ([-10, 10], 2, [-10, 10]),
        ([1, 2, 3, -23, 243, -400, 0], 0, []),
        # Additional edge cases
        ([100, 200, 50], 2, [100, 200]),
        ([-5, -3, -1], 3, [-5, -3, -1]),
        ([0, 0, 0, 0], 2, [0, 0]),
    ]
    
    passed = 0
    total = len(test_cases)
    
    for idx, (arr_list, k, expected) in enumerate(test_cases):
        dut._log.info(f"\nTest case {idx+1}: arr={arr_list}, k={k}")
        
        # Load array
        arr_len = len(arr_list)
        dut.arr_len.value = arr_len
        dut.k.value = k
        
        # Clear previous results
        for i in range(8):
            dut.arr[i].value = 0
        
        # Load input array
        for i, val in enumerate(arr_list):
            dut.arr[i].value = from_signed(val)
        
        # Start pulse
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done with cycle timeout
        max_cycles = 100
        done_received = False
        
        for cycle in range(max_cycles):
            await RisingEdge(dut.clk)
            
            if not is_value_defined(dut.done.value):
                continue
            
            if dut.done.value == 1:
                done_received = True
                break
        
        if not done_received:
            raise TestFailure(f"Test {idx+1}: Done signal not received after {max_cycles} cycles")
        
        # Verify results
        if k == 0:
            # k=0 should just complete with done
            dut._log.info(f"Test {idx+1}: k=0 case completed")
            passed += 1
            continue
        
        # Read results
        results = []
        for i in range(k):
            result_signal = [dut.result_0, dut.result_1, dut.result_2, dut.result_3][i]
            
            if not is_value_defined(result_signal.value):
                raise TestFailure(f"Test {idx+1}: result_{i} is undefined (X/Z)")
            
            result_val = to_signed(int(result_signal.value))
            results.append(result_val)
        
        # Check sorted order
        is_sorted = all(results[i] <= results[i+1] for i in range(len(results)-1))
        if not is_sorted:
            raise TestFailure(f"Test {idx+1}: Results not sorted: {results}")
        
        # Check values match expected
        if results != expected:
            raise TestFailure(f"Test {idx+1}: Expected {expected}, got {results}")
        
        dut._log.info(f"Test {idx+1}: PASSED - got {results}")
        passed += 1
    
    dut._log.info(f"\n{'='*50}")
    dut._log.info(f"SUMMARY: {passed}/{total} tests passed")
    dut._log.info(f"{'='*50}")
    
    if passed == total:
        raise TestSuccess("All tests passed!")
    else:
        raise TestFailure(f"{total - passed} test(s) failed")

@cocotb.test(timeout_time=200, timeout_unit="ms")
async def test_maximum_k_stress(dut):
    """Stress test with maximum values."""
    
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for i in range(8):
        dut.arr[i].value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test with max sized inputs
    test_arr = [32767, -32768, 1000, -1000, 0, 500, -500, 12345]
    k = 4
    expected = sorted([500, 1000, 12345, 32767])  # k largest, sorted ascending
    
    dut._log.info(f"Stress test: arr={test_arr}, k={k}")
    
    dut.arr_len.value = 8
    dut.k.value = k
    for i, val in enumerate(test_arr):
        dut.arr[i].value = from_signed(val)
    
    # Start
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    for cycle in range(50):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and dut.done.value == 1:
            break
    else:
        raise TestFailure("Stress test: timeout")
    
    # Verify
    results = []
    for i in range(k):
        res_sig = [dut.result_0, dut.result_1, dut.result_2, dut.result_3][i]
        if not is_value_defined(res_sig.value):
            raise TestFailure(f"Result {i} undefined")
        results.append(to_signed(int(res_sig.value)))
    
    if results != expected:
        raise TestFailure(f"Stress test failed: expected {expected}, got {results}")
    
    dut._log.info(f"Stress test PASSED: {results}")
    raise TestSuccess("Stress test passed!")
