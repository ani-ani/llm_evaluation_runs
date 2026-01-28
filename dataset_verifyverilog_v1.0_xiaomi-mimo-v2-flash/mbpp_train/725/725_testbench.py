import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import re

# Constants
DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 1000
STR_LEN_MAX = 64
MAX_TOKENS = 4

# Helpers
def is_value_defined(v):
    try:
        int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try:
        getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def pack_string(s, max_len=STR_LEN_MAX):
    # Pack ASCII string into 64-bit vector (8 chars max)
    # Char 0 (leftmost) in bits 63:56, char 1 in 55:48, ..., char 7 in 7:0
    packed = 0
    for i, ch in enumerate(s[:max_len]):
        if i >= 8:
            break
        code = ord(ch)
        packed |= (code & 0xFF) << (56 - (i * 8))
    return packed

def pack_chars_to_token(s):
    # Pack 8-char token into 64-bit slot for result checking
    packed = 0
    for i, ch in enumerate(s[:8]):
        if i >= 8:
            break
        code = ord(ch)
        packed |= (code & 0xFF) << (56 - (i * 8))
    return packed

def extract_expected(text):
    # Python regex equivalent for testing
    import re
    tokens = re.findall(r'"(.*?)"', text)
    return tokens

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

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_extract_quotation(dut):
    # Setup clock and reset if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational: simple delay
        await Timer(10, units='ns')

    test_cases = [
        ('Cortex "A53" Based "multi" tasking "Processor"', ['A53', 'multi', 'Processor']),
        ('Cast your "favorite" entertainment "apps"', ['favorite', 'apps']),
        ('Watch content "4k Ultra HD" resolution with "HDR 10" Support', ['4k Ultra HD', 'HDR 10']),
        ("Watch content '4k Ultra HD' resolution with 'HDR 10' Support", []),
        # Additional: unbalanced quotes for error
        ('Mismatched "quotes', []),
    ]

    passed = 0
    failed = 0

    for idx, (text, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {idx+1}: Input '{text}' -> Expected {expected}")
        try:
            # Pack input string to 64-bit
            packed_str = pack_string(text, STR_LEN_MAX)
            str_len = min(len([c for c in text if c == '"' and c in text]), STR_LEN_MAX)  # Approx len, use actual char count for scan
            str_len = min(len(text), STR_LEN_MAX)
            dut.str.value = packed_str
            dut.str_len.value = str_len

            if is_seq:
                # Start pulse
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')

            # Check error if unbalanced
            if '"' in text and text.count('"') % 2 != 0:
                if has_signal(dut, 'error') and is_value_defined(dut.error.value):
                    if int(dut.error.value) == 1:
                        cocotb.log.info(f"Test {idx+1}: Correctly detected error for unbalanced quotes")
                        passed += 1
                        continue
                    else:
                        raise TestFailure(f"Expected error for unbalanced quotes")

            # Read result
            if not is_value_defined(dut.result_len.value):
                raise TestFailure("result_len undefined")
            result_len = int(dut.result_len.value)
            if result_len != len(expected):
                raise TestFailure(f"Expected {len(expected)} tokens, got {result_len}")

            if result_len > 0:
                # Extract each token slot from 256-bit result
                result_val = int(dut.result.value)
                for i, exp_token in enumerate(expected):
                    # Slot i is 64 bits starting from (63 + i*64) : (i*64) ?
                    # Spec: result: 256-bit vector, packed ASCII bytes for extracted tokens. Format: [Token0:8 bytes] + [Token1:8 bytes] + ...
                    # Assume msb is Token0 (bits 255:192), then Token1 (191:128), Token2 (127:64), Token3 (63:0)
                    slot_shift = 256 - ((i + 1) * 64)  # Bits 255:192 for i=0
                    slot = (result_val >> slot_shift) & ((1 << 64) - 1)
                    
                    # Pack expected token to 64-bit
                    exp_packed = pack_chars_to_token(exp_token)
                    if slot != exp_packed:
                        # Debug: print extracted chars
                        extracted = []
                        for j in range(8):
                            ch_byte = (slot >> (56 - j * 8)) & 0xFF
                            if ch_byte != 0:
                                extracted.append(chr(ch_byte))
                        extracted_str = ''.join(extracted)
                        raise TestFailure(f"Token {i}: expected '{exp_token}', got '{extracted_str}' (packed {hex(slot)} vs {hex(exp_packed)})")
                cocotb.log.info(f"Test {idx+1}: Passed")
            else:
                cocotb.log.info(f"Test {idx+1}: No tokens (empty)")
            passed += 1

        except TestFailure as e:
            cocotb.log.error(f"Test {idx+1} FAIL: {e}")
            failed += 1

    if failed > 0:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
