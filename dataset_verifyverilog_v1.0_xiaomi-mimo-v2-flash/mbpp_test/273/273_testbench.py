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

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    max_val = (1 << (bits-1)) - 1
    min_val = -(1 << (bits-1))
    return max(min_val, min(max_val, v))

# Array assignment helper
async def write_array_signed(dut, name, vals, width=8):
    """Assign signed values to array elements"""
    for i in range(8):
        if i < len(vals):
            # Convert to signed representation
            v = vals[i]
            if v < 0:
                # For negative values, use two's complement for assignment
                dut.__getattr__(name)[i].value = ((1 << width) + v) & ((1 << width) - 1)
            else:
                dut.__getattr__(name)[i].value = v & ((1 << width) - 1)
        else:
            dut.__getattr__(name)[i].value = 0

@cocotb.test(timeout_time=100, timeout_unit="ms")
async def test_substract_elements(dut):
    """Test element-wise subtraction of two fixed-size arrays"""
    
    # Setup clock and reset
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases: (arr_a, arr_b, expected_result, description)
    test_cases = [
        ([10, 4, 5, 0, 0, 0, 0, 0], [2, 5, 18, 0, 0, 0, 0, 0], [8, -1, -13, 0, 0, 0, 0, 0], "Test 1: basic subtraction"),
        ([11, 2, 3, 0, 0, 0, 0, 0], [24, 45, 16, 0, 0, 0, 0, 0], [-13, -43, -13, 0, 0, 0, 0, 0], "Test 2: negative results"),
        ([7, 18, 9, 0, 0, 0, 0, 0], [10, 11, 12, 0, 0, 0, 0, 0], [-3, 7, -3, 0, 0, 0, 0, 0], "Test 3: mixed results")
    ]
    
    passed = 0
    failed = 0
    
    for i, (arr_a, arr_b, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {i+1}: {desc}")
        
        try:
            # Write arrays
            await write_array_signed(dut, 'arr_a', arr_a, 8)
            await write_array_signed(dut, 'arr_b', arr_b, 8)
            
            # Trigger computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done (timeout 50 cycles)
            done_seen = False
            for _ in range(50):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    done_seen = True
                    break
            
            if not done_seen:
                raise TestFailure("done signal not asserted within 50 cycles")
            
            # Read and verify results
            if not hasattr(dut, 'arr_res'):
                raise TestFailure("arr_res signal not found")
            
            errors = []
            for j in range(8):
                if not is_value_defined(dut.arr_res[j].value):
                    errors.append(f"arr_res[{j}] undefined")
                    continue
                
                # Read as 8-bit unsigned, interpret as signed
                result_raw = int(dut.arr_res[j].value)
                result = result_raw if result_raw < 128 else result_raw - 256
                exp_val = expected[j]
                
                if result != exp_val:
                    errors.append(f"arr_res[{j}]: expected {exp_val}, got {result}")
            
            if errors:
                raise TestFailure("; ".join(errors))
            
            cocotb.log.info(f"  PASS: Results match")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Prepare for next test - wait one cycle
        await RisingEdge(dut.clk)
    
    cocotb.log.info(f"\nResults: {passed} passed, {failed} failed")
    if failed:
        raise TestFailure(f"{failed} test(s) failed")