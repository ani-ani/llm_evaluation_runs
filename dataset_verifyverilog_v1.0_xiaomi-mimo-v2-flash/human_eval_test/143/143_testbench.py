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

def str_to_bits(s):
    """Convert string to integer bit representation (8-bit per char, little-endian for array access)"""
    res = 0
    for i, c in enumerate(s):
        res |= (ord(c) << (i * 8))
    return res

def bits_to_str(bits, length):
    """Convert integer bits back to string"""
    s = []
    for i in range(length):
        byte = (bits >> (i * 8)) & 0xFF
        if byte == 0:
            break
        s.append(chr(byte))
    return "".join(s)

def prime_check(n):
    """Check if n is prime (1-100)"""
    primes = {2,3,5,7,11,13,17,19,23,29,31,37,41,43,47,53,59,61,67,71,73,79,83,89,97}
    return n in primes

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_words_in_sentence(dut):
    # Setup clock if synchronous
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        await Timer(100, units='ns')
    
    test_cases = [
        ("This is a test", "is" ),
        ("lets go for swimming", "go for" ),
        ("there is no place available here", "there is no place" ),
        ("Hi I am Hussein", "Hi am Hussein" ),
        ("go for it", "go for it" ),
        ("here", "" ),
        ("here is", "is" ),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_str, expected_str) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: '{input_str}' -> '{expected_str}'")
        try:
            # 1. Prepare inputs
            input_bits = str_to_bits(input_str)
            input_len = len(input_str)
            
            # 2. Assign to DUT
            dut.sentence.value = input_bits
            dut.length.value = input_len
            
            # 3. Trigger start
            if has_signal(dut, 'start') and has_signal(dut, 'clk'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # 4. Wait for done
                done = False
                for _ in range(256):
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        done = True
                        break
                
                if not done:
                    raise TestFailure(f"Timeout waiting for done signal")
            else:
                await Timer(1000, units='ns')
            
            # 5. Read results
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            if not is_value_defined(dut.result_len.value):
                raise TestFailure("Result_len signal undefined")
            
            result_len = int(dut.result_len.value)
            result_bits = int(dut.result.value)
            
            # 6. Convert back to string and compare
            result_str = bits_to_str(result_bits, result_len)
            
            if result_str != expected_str:
                raise TestFailure(f"Expected '{expected_str}', got '{result_str}'")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL (Test {i+1}): {e}")
            failed += 1
            
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed, {passed} passed")
    else:
        cocotb.log.info(f"All {passed} tests passed!")