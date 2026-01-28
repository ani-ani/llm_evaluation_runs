import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import re

# MANDATORY HELPERS
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
    return min((1 << bits) - 1, max(0, v))

# ARRAY/STRING HELPER
def pack_string(s, max_len=15):
    """Pack string into 64-bit integer (8 chars, 8 bits each)."""
    res = 0
    # Pad with nulls (0x00) or spaces if needed, but here we just pack what we have
    # Input string must be ascii bytes
    for i in range(min(len(s), 8)): # Hardware input is limited to 8 chars per packet in spec? 
        # Spec says ip_in is 64-bit packed array of 8 characters. Max len_in 15.
        # Wait, 64 bits is 8 bytes. Input "216.08.094.0196" is 14 chars.
        # If input is packed 64-bit, it can only hold 8 chars.
        # Correction: The spec said "64-bit packed array of 8 characters". 
        # The Python test cases have strings up to 14 chars.
        # I will assume a wider bus or modify the testbench to handle 16 chars (128-bit) or just the first 8.
        # However, to match the Python tests strictly, let's assume the hardware handles 16 chars (128-bit) or the prompt implies scalable width.
        # Let's stick to 128-bit (16 chars) for the testbench to cover the cases.
        pass
    
    # Refined: Let's assume the Verilog spec actually accepts 128-bit for the test cases provided,
    # or the Python string is truncated. The prompt said "64-bit packed array of 8 characters".
    # Let's assume the Verilog spec is flexible or I need to make the testbench match the spec.
    # I will modify the logic to support 16 chars (128-bit) as the Python examples are long.
    # But if the spec says 64-bit, I must respect it. The Python test "216.08.094.0196" is 14 chars.
    # I will assume the prompt meant 128-bit for practicality, or I'll just pack the first 8 chars.
    # Let's use 128-bit to be safe with the test cases.
    pass

def pack_string_128(s):
    res = 0
    for i, ch in enumerate(s[:16]):
        res |= (ord(ch) & 0xFF) << (8 * i)
    return res

def pack_string_64(s):
    res = 0
    # Only first 8 chars
    for i, ch in enumerate(s[:8]):
        res |= (ord(ch) & 0xFF) << (8 * i)
    return res

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(10, units='ns')
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        if has_signal(dut, 'clk'):
            for _ in range(cycles): await RisingEdge(dut.clk)
        else:
            await Timer(cycles * 10, units='ns')
        dut.rst_n.value = 1
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(10, units='ns')

# LOGIC FOR REMOVAL (Reference)
def removezero_ip_ref(ip):
    # Python logic for verification
    # Split by dot
    parts = ip.split('.')
    new_parts = []
    for p in parts:
        # Remove leading zeros unless it's just "0"
        p = p.lstrip('0')
        if p == '': p = '0'
        new_parts.append(p)
    return '.'.join(new_parts)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_ip_remove_leading_zero(dut):
    # Interface adaptation: 
    # The prompt specified "64-bit packed array of 8 characters" but test cases are longer.
    # I will assume the DUT uses 128-bit (16 chars) to accommodate "216.08.094.0196".
    # If the DUT is actually 64-bit, this testbench needs width adjustment.
    # I will try to detect the width of 'ip_in' or default to 128-bit logic.
    
    DATA_WIDTH = 8
    MAX_CHARS = 16  # 128 bits
    CLK_NS = 10
    
    # Setup Clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await reset_dut(dut)

    # Test Cases
    test_cases = [
        ("216.08.094.196", "216.8.94.196"),
        ("12.01.024", "12.1.24"), # Note: 3 parts. Valid IP usually 4, but function handles it.
        ("216.08.094.0196", "216.8.94.196"),
        ("0.0.0.0", "0.0.0.0"),
        ("192.168.001.001", "192.168.1.1")
    ]

    for i, (inp, exp) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {inp} -> {exp}")
        
        # Prepare Input
        # Pack string into integer
        packed_in = 0
        for k, ch in enumerate(inp):
            packed_in |= (ord(ch) & 0xFF) << (8 * k)
        
        length_in = len(inp)
        
        # Drive Inputs
        if has_signal(dut, 'ip_in'):
            # Check width of ip_in
            try:
                width = len(dut.ip_in)
                dut.ip_in.value = packed_in
            except (TypeError, ValueError):
                # It might be a LogicArray, or just a single signal
                # If it's a single logic vector, assign integer
                dut.ip_in.value = packed_in
        
        if has_signal(dut, 'len_in'):
            dut.len_in.value = length_in
            
        if has_signal(dut, 'start'):
            dut.start.value = 1
            if has_signal(dut, 'clk'):
                await RisingEdge(dut.clk)
            else:
                await Timer(10, units='ns')
            dut.start.value = 0
        else:
            # Combinational logic might process immediately
            await Timer(100, units='ns')
            
        # Wait for Done
        try:
            await wait_for_done(dut, max_cycles=256)
        except TestFailure:
            # If no done signal (combinational), just wait a bit
            if not has_signal(dut, 'done'):
                await Timer(100, units='ns')
            else:
                raise

        # Read Output
        if not is_value_defined(dut.done.value) and has_signal(dut, 'done'):
             raise TestFailure("Done signal undefined")

        # Get Output String
        out_val = 0
        if has_signal(dut, 'ip_out'):
            out_val = int(dut.ip_out.value)
        
        out_len = 0
        if has_signal(dut, 'len_out'):
            out_len = int(dut.len_out.value)
        else:
            # If len_out not present, we infer length or just use MAX
            out_len = MAX_CHARS
            
        # Unpack Output
        out_str = ""
        for k in range(out_len):
            byte = (out_val >> (8 * k)) & 0xFF
            if byte != 0:
                out_str += chr(byte)
        
        cocotb.log.info(f"Output: {out_str} (Len: {out_len})")
        
        # Verify
        if out_str != exp:
            raise TestFailure(f"Expected '{exp}', got '{out_str}'")
