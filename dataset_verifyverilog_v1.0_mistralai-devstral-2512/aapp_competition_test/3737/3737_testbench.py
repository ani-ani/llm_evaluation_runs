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

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

# Testbench Configuration
DATA_WIDTH = 32
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 300

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_steward_support(dut):
    """Test the steward_support module"""
    
    # Setup clock and reset if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        await Timer(10, units='ns')

    # Test cases: (values_list, n, expected_count, description)
    test_cases = [
        ([1, 5], 2, 0, "Example 1: 2 elements"),
        ([1, 2, 5], 3, 1, "Example 2: 3 elements"),
        ([1, 2, 3, 4], 4, 2, "4 distinct elements"),
        ([1, 1, 1, 1], 4, 0, "All same"),
        ([5], 1, 0, "Single element"),
        ([10, 10, 5, 5], 4, 0, "Two groups, no strict between"),
        ([1, 2, 2, 3], 4, 1, "Duplicates in between"),
        ([7, 8, 9, 4, 5, 6, 1, 2], 8, 6, "Example from long list"),
        ([1000000000, 99999999, 1000000000, 1000000000], 4, 1, "Large values"),
        ([0, 0, 0, 1, 2], 5, 1, "Zeros and positives"),
        ([1, 2, 2, 2, 2, 2, 3], 7, 1, "Many duplicates"),
        ([1, 1, 1, 2, 2, 2, 4, 4, 4], 9, 2, "Three distinct groups"),
        ([1, 2, 3, 4, 1, 5, 6, 7, 8], 9, 6, "Unsorted distinct + duplicates")
    ]

    passed = 0
    failed = 0

    for i, (vals, n, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        
        # Prepare inputs
        # Ensure we don't exceed array size (which is 16)
        if n > ARRAY_SIZE:
            n = ARRAY_SIZE
            vals = vals[:ARRAY_SIZE]
            
        # Assign values to array elements (safely)
        if has_signal(dut, 'values'):
            # Handle array access (indexed)
            for j in range(ARRAY_SIZE):
                if j < n:
                    val = clamp_to_width(vals[j], DATA_WIDTH)
                else:
                    val = 0
                try:
                    dut.values[j].value = val
                except Exception:
                    # Fallback for flattened arrays (arr_0, arr_1...)
                    if hasattr(dut.values, '__len__'):
                        dut.values[j].value = val
                    else:
                        # If it's a single port logic, we might need to pack it, 
                        # but usually explicit array indices work in Verilog.
                        # Let's try dynamic attribute for 'values_0' style if 'values' failed
                        attr_name = f'values_{j}'
                        if has_signal(dut, attr_name):
                            getattr(dut, attr_name).value = val
                        else:
                            # If nothing works, log and assume single wire (unlikely for array)
                            pass
        elif has_signal(dut, 'values_0'):
             for j in range(min(n, ARRAY_SIZE)):
                 attr_name = f'values_{j}'
                 if has_signal(dut, attr_name):
                     getattr(dut, attr_name).value = clamp_to_width(vals[j], DATA_WIDTH)
        
        # Assign n
        if has_signal(dut, 'n'):
            dut.n.value = n
            
        # Trigger start
        if is_seq:
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done with timeout
            done_found = False
            for _ in range(MAX_CYCLES):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    done_found = True
                    break
            
            if not done_found:
                cocotb.log.error(f"Timeout waiting for done in test {i+1}")
                failed += 1
                continue
            
            # Read result
            if not is_value_defined(dut.result.value):
                cocotb.log.error(f"Result undefined in test {i+1}")
                failed += 1
                continue
                
            result = int(dut.result.value)
        else:
            # Combinational logic
            await Timer(50, units='ns') # Allow propagation
            if not is_value_defined(dut.result.value):
                cocotb.log.error(f"Result undefined in test {i+1}")
                failed += 1
                continue
            result = int(dut.result.value)

        if result == expected:
            cocotb.log.info(f"PASS: Got {result}")
            passed += 1
        else:
            cocotb.log.error(f"FAIL: Expected {expected}, got {result}")
            failed += 1

    if failed > 0:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    else:
        cocotb.log.info(f"All {passed} tests passed!")
