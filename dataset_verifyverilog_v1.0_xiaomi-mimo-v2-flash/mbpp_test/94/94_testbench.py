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

def str_to_packed(s, max_len=8):
    """Convert ASCII string to 64-bit packed value"""
    s = s[:max_len].ljust(max_len)
    return int.from_bytes(s.encode('ascii'), 'little')

def packed_to_str(p, max_len=8):
    """Convert 64-bit packed value to ASCII string"""
    b = p.to_bytes(8, 'little')
    return b.decode('ascii').rstrip('\x00')

async def wait_for_done(dut, max_cycles=256):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def write_tuples(dut, tuples):
    """Write array of tuples (string, value) to DUT"""
    if not tuples:
        dut.valid_tuples.value = 0
        return
    
    dut.valid_tuples.value = len(tuples)
    for i, (s, v) in enumerate(tuples):
        packed = str_to_packed(s)
        dut.tuple_str[i].value = packed
        dut.tuple_val[i].value = clamp_to_width(v, 16)
        dut.data_valid.value = 1
    await RisingEdge(dut.clk)
    dut.data_valid.value = 0

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_index_minimum(dut):
    """Test finding tuple with minimum second value"""
    # Setup
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    # Test cases matching original problem
    test_cases = [
        ([('Rash', 143), ('Manjeet', 200), ('Varsha', 100)], 'Varsha'),
        ([('Yash', 185), ('Dawood', 125), ('Sanya', 175)], 'Dawood'),
        ([('Sai', 345), ('Salman', 145), ('Ayesha', 96)], 'Ayesha'),
    ]
    
    passed = failed = 0
    for i, (tuples, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: Expected '{expected}' from {len(tuples)} tuples")
        try:
            # Write tuples to DUT
            await write_tuples(dut, tuples)
            
            # Start processing
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(1000, units='ns')
            
            # Check result
            if not is_value_defined(dut.result_str.value):
                raise TestFailure("Result string undefined")
            
            result_packed = int(dut.result_str.value)
            result_str = packed_to_str(result_packed)
            
            # Handle error flag
            if has_signal(dut, 'error') and is_value_defined(dut.error.value):
                if int(dut.error.value) == 1:
                    raise TestFailure(f"Error flag set (no valid tuples)")
            
            if result_str != expected:
                raise TestFailure(f"Expected '{expected}', got '{result_str}'")
            
            passed += 1
            cocotb.log.info(f"  PASS: Got '{result_str}'")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Edge case: empty list
    cocotb.log.info("Test empty tuples list")
    try:
        await write_tuples(dut, [])
        if is_seq:
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut)
        else:
            await Timer(1000, units='ns')
        
        if has_signal(dut, 'error'):
            if int(dut.error.value) != 1:
                raise TestFailure("Error flag should be set for empty list")
        else:
            # If no error flag, check result is 0
            if is_value_defined(dut.result_str.value):
                if int(dut.result_str.value) != 0:
                    raise TestFailure("Result should be 0 for empty list")
        passed += 1
        cocotb.log.info("  PASS: Empty list handled")
    except TestFailure as e:
        cocotb.log.error(f"  FAIL: {e}")
        failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
    cocotb.log.info(f"All {passed} tests passed!")
