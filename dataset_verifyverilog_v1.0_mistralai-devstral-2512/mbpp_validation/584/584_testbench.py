import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

def to_char(v):
    return chr(v) if v >= 32 and v < 127 else '?'

def pack_string(s, max_len=16):
    result = 0
    for i in range(max_len):
        if i < len(s):
            result |= ord(s[i]) << (i * 8)
        else:
            result |= 0 << (i * 8)
    return result

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_find_adverbs(dut):
    CLK_NS = 10
    MAX_CYCLES = 100
    
    # Setup clock and reset
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        await RisingEdge(dut.clk)
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    test_cases = [
        ("Clearly, he has no excuse for such behavior.", 0, 7, True, "Clearly"),
        ("Please handle the situation carefuly", 28, 36, True, "carefuly"),
        ("Complete the task quickly", 18, 25, True, "quickly"),
        ("No adverb here", None, None, False, "none"),
        ("ly test", 0, 2, True, "ly"),
        ("test ly", 5, 7, True, "ly"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (text, exp_start, exp_end, should_find, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} in '{text}'")
        try:
            dut.start.value = 0
            await RisingEdge(dut.clk)
            
            packed = pack_string(text, 16)
            if has_signal(dut, 'data'):
                dut.data.value = packed
            else:
                # Individual array access
                for j in range(16):
                    if j < len(text):
                        getattr(dut, f'data_{j}').value = ord(text[j])
                    else:
                        getattr(dut, f'data_{j}').value = 0
            
            if has_signal(dut, 'len'):
                dut.len.value = min(len(text), 16)
            
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            done_found = False
            for _ in range(MAX_CYCLES):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    done_found = True
                    break
            
            if not done_found:
                raise TestFailure(f"Timeout waiting for done signal")
            
            if has_signal(dut, 'valid'):
                found = int(dut.valid.value) == 1
            else:
                # Check if result indicates valid
                found = True  # Assume valid if not signaled
            
            if should_find != found:
                raise TestFailure(f"Expected {'find' if should_find else 'not find'}, but got found={found}")
            
            if should_find:
                start_val = int(dut.start_pos.value) if has_signal(dut, 'start_pos') else None
                end_val = int(dut.end_pos.value) if has_signal(dut, 'end_pos') else None
                
                if start_val != exp_start or end_val != exp_end:
                    raise TestFailure(f"Expected ({exp_start}, {exp_end}), got ({start_val}, {end_val})")
                
                # Extract substring from data
                if has_signal(dut, 'data'):
                    data_val = int(dut.data.value)
                    extracted = []
                    for j in range(start_val, end_val):
                        byte = (data_val >> (j * 8)) & 0xFF
                        extracted.append(chr(byte))
                    result_word = ''.join(extracted)
                    if result_word != desc:
                        raise TestFailure(f"Expected '{desc}', got '{result_word}'")
            
            passed += 1
            cocotb.log.info(f"PASS: {desc}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: Test {i+1} ({desc}): {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
