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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def str_to_ascii_array(s, width=8, max_len=16):
    # Returns a list of integers (ASCII codes)
    vals = [ord(c) for c in s]
    if len(vals) > max_len:
        raise ValueError(f"String '{s}' exceeds max length {max_len}")
    return vals

def ascii_array_to_str(vals):
    return ''.join(chr(v) for v in vals if v != 0)

def pack_array(vals, bits=8):
    r = 0
    for i, v in enumerate(vals):
        r |= (v & ((1 << bits) - 1)) << (i * bits)
    return r

async def write_input(dut, text, length):
    # text is list of ints
    # Pack into text_in signal
    dut.text_in.value = pack_array(text)
    dut.len_in.value = length

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_fix_spaces(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)

    # Test cases: (Input String, Expected Output String)
    test_cases = [
        ("Example", "Example"),
        ("Mudasir Hanif ", "Mudasir_Hanif_"),
        ("Yellow Yellow  Dirty  Fellow", "Yellow_Yellow__Dirty__Fellow"),
        ("Exa   mple", "Exa-mple"),
        ("   Exa 1 2 2 mple", "-Exa_1_2_2_mple")
    ]

    passed = 0
    failed = 0

    for i, (inp_str, exp_str) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: '{inp_str}' -> '{exp_str}'")
        
        try:
            # Prepare input
            in_vals = str_to_ascii_array(inp_str)
            in_len = len(in_vals)
            
            # Write to DUT
            dut.start.value = 1
            await write_input(dut, in_vals, in_len)
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read output
            out_len = int(dut.len_out.value)
            out_packed = int(dut.text_out.value)
            
            # Unpack output
            out_vals = []
            for j in range(out_len):
                val = (out_packed >> (j * 8)) & 0xFF
                out_vals.append(val)
            
            out_str = ascii_array_to_str(out_vals)
            
            # Verify
            if out_str != exp_str:
                raise TestFailure(f"Mismatch. Expected '{exp_str}', got '{out_str}' (Len {out_len})")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        
        # Reset for next test
        await reset_dut(dut)

    if failed:
        raise TestFailure(f"{failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed")
