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

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# FP helpers
def float_to_fixed(f, frac=16):
    return int(f * (1 << frac))

def fixed_to_float(v, frac=16):
    return v / (1 << frac)

# Convert string to fixed-point (Q16.16) or alphabetic encoding
def str_to_output(s, width=32):
    s_clean = s.strip()
    # Check if alphabetic
    if any(c.isalpha() for c in s_clean):
        # Take first alphabetic char, or first char if all alpha
        first_alpha = next((c for c in s_clean if c.isalpha()), s_clean[0] if s_clean else ' ')
        ascii_val = ord(first_alpha) & 0xFF
        return (ascii_val << 24) & ((1 << width) - 1)
    # Numeric conversion
    if '.' in s_clean:
        parts = s_clean.split('.')
        int_part = int(parts[0]) if parts[0] else 0
        frac_part = int(parts[1]) if len(parts) > 1 else 0
        # Scale to 100ths: total = int_part * 100 + frac_part (assuming frac digits <= 2)
        total = int_part * 100 + frac_part
        # Multiply by 65536 and divide by 100
        fixed_val = (total * 65536) // 100
    else:
        int_val = int(s_clean) if s_clean else 0
        fixed_val = int_val * 65536
    return fixed_val & ((1 << width) - 1)

# Pack string into 64-bit (8 bytes) for input ports
def pack_string_to_64(s, max_len=8):
    s_padded = s.ljust(max_len, ' ')
    val = 0
    for i in range(max_len):
        val |= (ord(s_padded[i]) & 0xFF) << (8 * i)
    return val

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_list_to_float(dut):
    # Check if sequential (has clk)
    is_seq = has_signal(dut, 'clk')
    CLK_NS = 10
    
    if is_seq:
        # Setup clock
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        for _ in range(2): await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        # Combinational
        await Timer(10, units='ns')
    
    # Define test cases (4 pairs each)
    test_cases = [
        ([("3", "4"), ("1", "26.45"), ("7.32", "8"), ("4", "8")], 
         [(3.0, 4.0), (1.0, 26.45), (7.32, 8.0), (4.0, 8.0)]),
        ([("4", "4"), ("2", "27"), ("4.12", "9"), ("7", "11")], 
         [(4.0, 4.0), (2.0, 27.0), (4.12, 9.0), (7.0, 11.0)]),
        ([("6", "78"), ("5", "26.45"), ("1.33", "4"), ("82", "13")], 
         [(6.0, 78.0), (5.0, 26.45), (1.33, 4.0), (82.0, 13.0)])
    ]
    
    passed = 0
    failed = 0
    
    for case_idx, (inp_pairs, exp_pairs) in enumerate(test_cases):
        cocotb.log.info(f"Test case {case_idx+1}: Input {inp_pairs}")
        
        # Prepare inputs: 4 pairs, each with 2 strings (str_0 and str_1)
        # We'll write to dut inputs. For sequential, start must be pulsed.
        # For each pair, we have signals: pair_i_str_0, pair_i_str_1 (each 64-bit)
        for i in range(4):
            if i < len(inp_pairs):
                s0, s1 = inp_pairs[i]
            else:
                s0, s1 = "", ""
            # Pack strings to 64-bit
            val_s0 = pack_string_to_64(s0)
            val_s1 = pack_string_to_64(s1)
            # Set signals
            if has_signal(dut, f'pair_{i}_str_0'):
                getattr(dut, f'pair_{i}_str_0').value = val_s0
            if has_signal(dut, f'pair_{i}_str_1'):
                getattr(dut, f'pair_{i}_str_1').value = val_s1
        
        # Start processing
        if is_seq:
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                # Wait for done
                done = False
                for _ in range(1000):  # timeout cycles
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        done = True
                        break
                if not done:
                    cocotb.log.error(f"Test {case_idx+1} timeout")
                    failed += 1
                    continue
            else:
                await Timer(1000, units='ns')  # combinatorial delay
        else:
            await Timer(100, units='ns')  # combinatorial delay
        
        # Read outputs for 4 pairs
        try:
            for i in range(4):
                if i >= len(exp_pairs):
                    break
                exp_val0 = float_to_fixed(exp_pairs[i][0])
                exp_val1 = float_to_fixed(exp_pairs[i][1])
                
                # Read from dut
                val0 = None
                val1 = None
                if has_signal(dut, f'result_pair_{i}_val_0'):
                    val0 = int(getattr(dut, f'result_pair_{i}_val_0').value)
                if has_signal(dut, f'result_pair_{i}_val_1'):
                    val1 = int(getattr(dut, f'result_pair_{i}_val_1').value)
                
                if val0 is None or val1 is None:
                    raise TestFailure(f"Output for pair {i} not found")
                
                if val0 != exp_val0:
                    raise TestFailure(f"Pair {i} val0: expected {exp_val0}, got {val0} (float {fixed_to_float(val0)})")
                if val1 != exp_val1:
                    raise TestFailure(f"Pair {i} val1: expected {exp_val1}, got {val1} (float {fixed_to_float(val1)})")
                
            cocotb.log.info(f"Test {case_idx+1} passed")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"Test {case_idx+1} FAIL: {e}")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
