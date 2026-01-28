import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_even_filter(dut):
    """Test even number filter module"""
    
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        # Setup clock
        clock = Clock(dut.clk, 10, units='ns')
        cocotb.start_soon(clock.start())
        
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        ([1,2,3,4,5], 5, [2,4,0,0,0,0,0,0], 2, "Odd and even mix"),
        ([4,5,6,7,8,0,1], 7, [4,6,8,0,0,0,0,0], 4, "Multiple evens"),
        ([8,12,15,19], 4, [8,12,0,0,0,0,0,0], 2, "First two even"),
        ([1,3,5,7,9], 5, [0,0,0,0,0,0,0,0], 0, "All odd"),
        ([0,2,4,6,8,10,12,14], 8, [0,2,4,6,8,10,12,14], 8, "All even max"),
    ]
    
    passed = failed = 0
    
    for test_idx, (input_vals, inp_len, expected_result, expected_count, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {test_idx+1}: {desc}")
        
        try:
            # Write input array
            if has_signal(dut, 'arr'):
                for i, val in enumerate(input_vals):
                    if i < 16:
                        dut.arr[i].value = clamp_to_width(val if val >= 0 else (1 << 8) + val, 8)
            else:
                # Individual ports
                for i in range(16):
                    signal_name = f'arr_{i}'
                    if hasattr(dut, signal_name):
                        if i < inp_len:
                            val = input_vals[i]
                            getattr(dut, signal_name).value = clamp_to_width(val if val >= 0 else (1 << 8) + val, 8)
                        else:
                            getattr(dut, signal_name).value = 0
            
            # Write length
            if has_signal(dut, 'len'):
                dut.len.value = inp_len
            
            # Start processing
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                done_received = False
                for cycle in range(1000):
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        done_received = True
                        break
                
                if not done_received:
                    raise TestFailure(f"Timeout waiting for done signal")
            else:
                # Combinational - wait for propagation
                await Timer(100, units='ns')
            
            # Read outputs
            if not is_value_defined(dut.result_count.value):
                raise TestFailure("result_count is undefined")
            
            result_count = int(dut.result_count.value)
            if result_count != expected_count:
                raise TestFailure(f"Expected count {expected_count}, got {result_count}")
            
            # Read result array
            result_array = []
            for i in range(8):
                val = None
                if has_signal(dut, 'result'):
                    val = dut.result[i].value
                else:
                    val = getattr(dut, f'result_{i}').value
                
                if is_value_defined(val):
                    v_int = int(val)
                    # Handle signed 8-bit
                    if v_int >= 128:
                        v_int -= 256
                    result_array.append(v_int)
                else:
                    result_array.append(0)
            
            # Compare result arrays
            for i in range(8):
                exp = expected_result[i]
                got = result_array[i]
                if got != exp:
                    raise TestFailure(f"Result[{i}]: expected {exp}, got {got}")
            
            cocotb.log.info(f"  PASS: Found {result_count} evens: {result_array[:result_count]}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed}/{passed+failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed")