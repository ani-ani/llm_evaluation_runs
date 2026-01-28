import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 16
CLK_NS = 10
MAX_CYCLES = 10000

# Helpers
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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=20000, timeout_unit="ms")
async def test_find_string(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational, just wait for stability
        await Timer(100, units='ns')

    # Python function to count pairs in a binary string
    def count_pairs(s):
        c00, c01, c10, c11 = 0, 0, 0, 0
        n = len(s)
        for i in range(n):
            for j in range(i + 1, n):
                if s[i] == '0' and s[j] == '0': c00 += 1
                elif s[i] == '0' and s[j] == '1': c01 += 1
                elif s[i] == '1' and s[j] == '0': c10 += 1
                elif s[i] == '1' and s[j] == '1': c11 += 1
        return c00, c01, c10, c11

    test_cases = [
        (3, 4, 2, 1), # Expected: 01001 (or similar)
        (5, 0, 0, 5), # Impossible
        (0, 0, 0, 1), # Valid: "11" -> 1 pair of 11
        (1, 0, 0, 0), # Valid: "00"
        (0, 1, 1, 0), # Valid: "01"
        (6, 3, 2, 1), # Likely impossible for small strings
    ]

    for a, b, c, d in test_cases:
        cocotb.log.info(f"Testing a={a}, b={b}, c={c}, d={d}")
        
        # Set inputs
        if has_signal(dut, 'a'): dut.a.value = clamp_to_width(a, DATA_WIDTH)
        if has_signal(dut, 'b'): dut.b.value = clamp_to_width(b, DATA_WIDTH)
        if has_signal(dut, 'c'): dut.c.value = clamp_to_width(c, DATA_WIDTH)
        if has_signal(dut, 'd'): dut.d.value = clamp_to_width(d, DATA_WIDTH)

        if is_seq:
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
            await wait_for_done(dut)
        else:
            await Timer(100, units='ns')

        # Read output
        if not has_signal(dut, 'out_len'):
             raise TestFailure("Missing out_len signal")
        
        out_len = int(dut.out_len.value)
        out_chars = []
        
        # Read up to 16 chars (handles both array and individual signals)
        for i in range(16):
            if has_signal(dut, f'out_chars_{i}'):
                out_chars.append(int(getattr(dut, f'out_chars_{i}').value))
            elif has_signal(dut, 'out_chars'):
                 try:
                     # Check if index exists
                     val = int(dut.out_chars[i].value)
                     out_chars.append(val)
                 except Exception:
                     break
            else:
                break

        # Construct string
        actual_str = ""
        if out_len > 0:
            for i in range(out_len):
                if i < len(out_chars):
                    actual_str += str(out_chars[i])
                else:
                    # Fallback if signals not properly read
                    break
        
        # Verify
        expected = "impossible"
        
        # Manual check in Python for validity since HDL might be slow/complex
        # We just check if the output string satisfies counts
        
        if out_len == 0:
            # Should be impossible. Verify that no short string exists.
            # Check lengths 2 to 16
            found_any = False
            for L in range(2, 17):
                # Quick prune: total pairs must be <= L*(L-1)/2
                if a + b + c + d > L * (L - 1) // 2: continue
                # Iterate 2^L possibilities
                for mask in range(1 << L):
                    s = ''.join(str((mask >> (L - 1 - k)) & 1) for k in range(L))
                    c00, c01, c10, c11 = count_pairs(s)
                    if c00 == a and c01 == b and c10 == c and c11 == d:
                        found_any = True
                        break
                if found_any: break
            if found_any:
                 raise TestFailure(f"Output len 0, but solution exists for a={a},b={b},c={c},d={d}")
        else:
            # Check if string matches
            if len(actual_str) != out_len:
                raise TestFailure(f"Length mismatch: signal {out_len}, counted {len(actual_str)}")
            
            c00, c01, c10, c11 = count_pairs(actual_str)
            if c00 != a or c01 != b or c10 != c or c11 != d:
                raise TestFailure(f"Counts mismatch. Str '{actual_str}': got 00={c00},01={c01},10={c10},11={c11}. Expected {a},{b},{c},{d}")

        cocotb.log.info(f"Success: len={out_len}, str='{actual_str}'")
