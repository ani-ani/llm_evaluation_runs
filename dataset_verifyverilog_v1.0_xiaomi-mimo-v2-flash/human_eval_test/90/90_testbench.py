import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    if v < 0:
        # Convert to signed 2's complement for the width
        v = v + (1 << bits)
        v = v & max_val
        # Convert back to python int (cocotb expects unsigned or proper handling)
        # Actually, cocotb assigns integer values. Let's treat all as unsigned for assignment
        # but the HDL interprets it as signed if declared.
        # To be safe: handle the negative conversion manually for the value.
        return v
    else:
        return v & max_val

def to_signed(val, bits):
    # Convert python int to signed int (handling overflows if necessary, but input should be in range)
    if val >= (1 << (bits-1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    # Convert signed int to python int for comparison
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# Main Testbench
@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_next_smallest(dut):
    # Setup
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 'clk'):
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
    else:
        await Timer(100, units='ns')
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        # (input_list, expected_result, expected_valid)
        ([1, 2, 3, 4, 5], 2, 1),
        ([5, 1, 4, 3, 2], 2, 1),
        ([], None, 0),
        ([1, 1], None, 0),
        ([1, 1, 1, 1, 0], 1, 1),  # Distinct values: 0, 1. Second smallest is 1.
        ([1, 1], None, 0),
        ([-35, 34, 12, -45], -35, 1), # Distinct: -45, -35, 12, 34. Second: -35.
        ([5, 5, 5, 5, 5], None, 0), # All equal
        ([10, 5, 2, 8], 5, 1) # 2, 5, 8, 10 -> 5
    ]

    passed = 0
    failed = 0
    DATA_WIDTH = 8

    for i, (inp, expected, exp_valid) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: Input {inp}")
        
        # Write inputs
        length = len(inp)
        if has_signal(dut, 'len'):
            dut.len.value = length
        
        # Write array elements (assuming 8 inputs exist)
        for idx in range(8):
            val = inp[idx] if idx < length else 0
            # Handle signed conversion for assignment to logic vector
            assign_val = val
            if val < 0:
                assign_val = (1 << DATA_WIDTH) + val
            
            # Check if signal exists (some synthesis might optimize unused)
            sig_name = f'arr_{idx}'
            if has_signal(dut, sig_name):
                getattr(dut, sig_name).value = assign_val
            elif hasattr(dut, 'arr'):
                 # Array access (requires specific HDL structure)
                 # Try standard array access if available
                 try:
                     dut.arr[idx].value = assign_val
                 except Exception:
                     pass
        
        # Start
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
        
        # Wait for done or timeout
        if has_signal(dut, 'done'):
            done = False
            for _ in range(200): # Timeout limit
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    done = True
                    break
            
            if not done:
                cocotb.log.error(f"Timeout waiting for done in test {i+1}")
                failed += 1
                continue
        else:
            await Timer(2000, units='ns')

        # Check Results
        if has_signal(dut, 'result') and has_signal(dut, 'valid'):
            # Read result
            res_val = int(dut.result.value)
            valid_val = int(dut.valid.value)
            
            # Convert result back to signed for comparison
            # (Assuming dut.result is declared as logic signed in Verilog)
            res_signed = to_signed(res_val, DATA_WIDTH)
            
            # Compare
            if valid_val != exp_valid:
                cocotb.log.error(f"Test {i+1} Failed: Expected valid={exp_valid}, got {valid_val}")
                failed += 1
            elif valid_val == 1 and res_signed != expected:
                cocotb.log.error(f"Test {i+1} Failed: Expected {expected}, got {res_signed}")
                failed += 1
            else:
                passed += 1
                cocotb.log.info(f"Test {i+1} Passed")
        else:
            cocotb.log.error("Required signals 'result' or 'valid' missing")
            failed += 1

    if failed > 0:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
