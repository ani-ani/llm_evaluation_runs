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

# Test constants
DATA_WIDTH = 8
MAX_N = 16
CLK_NS = 10
MAX_CYCLES = 1000

async def wait_for_done(dut, max_cycles=1000):
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

def pack_word(chars):
    packed = 0
    for i, c in enumerate(chars):
        packed |= (ord(c) & 0xFF) << (i * 8)
    return packed

def unpack_word(val):
    chars = []
    for i in range(8):
        c = (val >> (i * 8)) & 0xFF
        if c == 0:
            break
        chars.append(chr(c))
    return ''.join(chars)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_slavko_game(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases
    test_cases = [
        ("2\nne\n", "NE", "n"),
        ("4\nkava\n", "DA", "ak"),
        ("8\ncokolada\n", "DA", "acko"),
    ]
    
    passed = 0
    failed = 0
    
    for tc_idx, (input_str, exp_out1, exp_out2) in enumerate(test_cases):
        cocotb.log.info(f"Test case {tc_idx+1}: {input_str[:20]}...")
        try:
            lines = input_str.strip().split('\n')
            n = int(lines[0])
            seq = lines[1]
            if len(seq) != n:
                raise TestFailure(f"Input length mismatch: {len(seq)} vs {n}")
            
            # Send N letters
            if is_seq:
                for i in range(n):
                    await RisingEdge(dut.clk)
                    dut.char_in.value = ord(seq[i]) & 0xFF
                    dut.start.value = 1 if i == 0 else 0
                
                # Wait for processing
                await wait_for_done(dut, MAX_CYCLES)
            else:
                # Combinational: set inputs directly
                dut.len.value = n
                for i in range(n):
                    getattr(dut, f'char_{i}').value = ord(seq[i]) & 0xFF
                await Timer(100, units='ns')
            
            # Check result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result_val = int(dut.result.value)
            slavko_word = unpack_word(result_val)
            
            # Compute expected manually
            remaining = list(seq)
            slavko_chars = []
            mirko_chars = []
            turn_slavko = True
            
            # Simulate: Mirko always takes rightmost, Slavko takes smallest available
            while remaining:
                if not turn_slavko:  # Mirko's turn (he goes second? No, Mirko first)
                    # Actually, problem: Mirko first, takes rightmost
                    # So turn Slavko = False means Mirko
                    pass
            
            # Correct simulation:
            # Mirko (player 1) goes first, takes rightmost. Slavko (player 2) takes any (smallest).
            # Remaining = list(seq)
            # For i in range(n/2):
            #   Mirko: pop rightmost
            #   Slavko: find min char in remaining, pop it
            rem = list(seq)
            mirko_w = []
            slavko_w = []
            for turn in range(n // 2):
                # Mirko
                mirko_c = rem.pop()  # rightmost
                mirko_w.append(mirko_c)
                # Slavko
                min_idx = 0
                for j in range(len(rem)):
                    if rem[j] < rem[min_idx]:
                        min_idx = j
                slavko_c = rem.pop(min_idx)
                slavko_w.append(slavko_c)
            
            # Words are in order of taking
            mirko_word = ''.join(mirko_w)
            slavko_word_exp = ''.join(slavko_w)
            
            if slavko_word != slavko_word_exp:
                raise TestFailure(f"Slavko word mismatch: got '{slavko_word}', expected '{slavko_word_exp}'")
            
            # Check win
            win_val = int(dut.win.value) if is_value_defined(dut.win.value) else 0
            if exp_out1 == "DA":
                if slavko_word >= mirko_word:
                    raise TestFailure(f"Should win but '{slavko_word}' >= '{mirko_word}'")
                if win_val != 1:
                    raise TestFailure(f"Win signal should be 1, got {win_val}")
            else:
                if slavko_word >= mirko_word and win_val == 1:
                    raise TestFailure(f"Should lose but win signal is 1")
            
            cocotb.log.info(f"PASS: Slavko='{slavko_word}', Mirko='{mirko_word}'")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")