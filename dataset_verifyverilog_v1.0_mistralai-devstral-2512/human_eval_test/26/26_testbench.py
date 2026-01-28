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
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

async def wait_for_done(dut, max_cycles=500):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_remove_duplicates(dut):
    # Check if it's a sequential module
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        clock = Clock(dut.clk, 10, units='ns')
        cocotb.start_soon(clock.start())
        await reset_dut(dut)
    
    # Test cases
    test_cases = [
        ([], 0, "empty array"),
        ([1, 2, 3, 4], 4, "no duplicates"),
        ([1, 2, 3, 2, 4, 3, 5], 3, "with duplicates"),
        ([1, 1, 1, 1], 1, "all same"),
        ([5, 1, 5, 2, 1], 2, "repeated at different positions"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_list, exp_len, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Create full 16-element array (zero-padded)
            full_arr = input_list + [0] * (16 - len(input_list))
            
            # Write input array
            for j in range(16):
                dut.arr[j].value = clamp_to_width(full_arr[j], 8)
            
            # Set length
            if has_signal(dut, 'len'):
                dut.len.value = len(input_list)
            
            if is_seq:
                # Start processing
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut, max_cycles=500)
            else:
                # Combinational - wait for stability
                await Timer(100, units='ns')
            
            # Read results
            if not is_value_defined(dut.out_len.value):
                raise TestFailure("out_len undefined")
            
            out_len = int(dut.out_len.value)
            
            if out_len != exp_len:
                raise TestFailure(f"Expected out_len={exp_len}, got {out_len}")
            
            # Read result array and check uniqueness
            result = []
            for j in range(16):
                val = int(dut.result[j].value)
                if j < out_len:
                    result.append(val)
            
            # Verify uniqueness (no duplicates in result)
            if len(result) != len(set(result)):
                raise TestFailure(f"Result contains duplicates: {result}")
            
            # Verify order matches input
            # Check that each element in result appears in input at that relative order
            input_pos = 0
            for res_val in result:
                found = False
                for k in range(len(input_list)):
                    if input_list[k] == res_val:
                        if k >= input_pos:
                            input_pos = k + 1
                            found = True
                            break
                if not found:
                    raise TestFailure(f"Result value {res_val} not found in input in correct order")
            
            passed += 1
            cocotb.log.info(f"  PASS: result={result}, out_len={out_len}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed")
