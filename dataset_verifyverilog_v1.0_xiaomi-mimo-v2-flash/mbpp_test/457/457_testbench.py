import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
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

def pack_bytes(bytes_list, max_len=8):
    """Pack up to 8 bytes into a 64-bit integer."""
    packed = 0
    for i, b in enumerate(bytes_list[:max_len]):
        packed |= (b & 0xFF) << (i * 8)
    return packed

def get_len_from_packed(packed, max_len=8):
    """Determine length by finding first null byte or max_len."""
    for i in range(max_len):
        byte = (packed >> (i * 8)) & 0xFF
        if byte == 0:
            return i
    return max_len

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def pack_and_write_sublists(dut, sublists):
    """Pack each sublist and write to dut ports."""
    valid_lens = []
    for i, lst in enumerate(sublists[:4]):  # Max 4 sublists
        # Convert chars to ASCII codes, pad with nulls
        bytes_list = [ord(c) for c in lst]
        packed = pack_bytes(bytes_list)
        # Compute length (pre-computed for hardware)
        actual_len = get_len_from_packed(packed)
        valid_lens.append(actual_len)
        
        # Write to packed port
        getattr(dut, f'sublist_packed_{i}').value = packed
        getattr(dut, f'valid_len_{i}').value = clamp_to_width(actual_len, 4)
    
    # Fill remaining sublists with zeros
    for i in range(len(sublists), 4):
        getattr(dut, f'sublist_packed_{i}').value = 0
        getattr(dut, f'valid_len_{i}').value = 0
    
    return valid_lens

def find_expected_min(sublists):
    """Python-side min finder for expected value."""
    if not sublists:
        return None, None
    min_idx = 0
    min_len = len(sublists[0])
    for i in range(1, len(sublists)):
        if len(sublists[i]) < min_len:
            min_len = len(sublists[i])
            min_idx = i
    return sublists[min_idx], min_len

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_min_sublist(dut):
    # Setup clock if sequential
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational: no clock/reset
        dut.rst_n.value = 1

    # Test cases based on Python problem
    test_cases = [
        ([['x'], ['x','y'], ['x','y','z']], ['x'], 1, "Single char vs longer"),
        ([['a','a'], ['a','a','a'], ['a','b','c','d']], ['a','a'], 2, "Two equal shortest"),
        ([['1'], ['1','2'], ['1','2','3']], ['1'], 1, "Number chars"),
        ([['z','z','z','z'], ['y'], ['x','x']], ['y'], 1, "Shortest in middle"),
        ([['a']*8, ['b']*4, ['c']*2], ['c']*2, 2, "Max length sublists"),
    ]

    passed = failed = 0

    for i, (inp_lists, exp_list, exp_len, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Prepare inputs
            valid_lens = await pack_and_write_sublists(dut, inp_lists)
            
            # Set start pulse
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut, max_cycles=100)
            else:
                # Combinational: wait for propagation
                await Timer(10, units='ns')
            
            # Read outputs
            if not is_value_defined(dut.result_packed.value):
                raise TestFailure("result_packed undefined")
            if not is_value_defined(dut.result_len.value):
                raise TestFailure("result_len undefined")
            
            result_packed = int(dut.result_packed.value)
            result_len = int(dut.result_len.value)
            
            # Convert back to bytes for comparison
            result_bytes = []
            for b in range(exp_len):
                result_bytes.append((result_packed >> (b * 8)) & 0xFF)
            
            # Expected packed value
            exp_packed = pack_bytes(exp_list)
            
            # Verify
            if result_len != exp_len:
                raise TestFailure(f"Length mismatch: expected {exp_len}, got {result_len}")
            if result_packed != exp_packed:
                raise TestFailure(f"Value mismatch: expected packed {exp_packed}, got {result_packed}")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL (Test {i+1}): {e}")
            failed += 1

    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
