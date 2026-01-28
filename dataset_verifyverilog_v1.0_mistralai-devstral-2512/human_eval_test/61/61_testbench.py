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

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def pack_string(s, max_len=16):
    """Pack ASCII string into 16x8-bit value"""
    result = 0
    chars = list(s)[:max_len]
    for i, c in enumerate(chars):
        result |= (ord(c) & 0xFF) << (i * 8)
    return result

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_correct_bracketing(dut):
    """Test bracket balancing algorithm"""
    
    # Check if sequential module
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        clk = Clock(dut.clk, 10, units='ns')
        cocotb.start_soon(clk.start())
        await reset_dut(dut)
    else:
        # Combinational module - no clock
        await Timer(100, units='ns')
    
    # Test cases: (input_string, expected_result, description)
    test_cases = [
        ("()", 1, "simple balanced"),
        ("(())", 1, "nested balanced"),
        ("(()())", 1, "complex nested"),
        ("()()(()())()", 1, "multiple balanced pairs"),
        ("()()((()()())())(()()(()))", 1, "very complex balanced"),
        (")", 0, "unbalanced: close first"),
        ("(", 0, "unbalanced: open only"),
        ("((", 0, "unbalanced: two opens"),
        ("))", 0, "unbalanced: two closes"),
        (")(", 0, "unbalanced: close then open"),
        ("(()", 0, "unbalanced: missing close"),
        ("()()(()())())(()", 0, "unbalanced: extra close"),
        ("()()(()())()))()", 0, "unbalanced: extra close at end"),
        ("((()())))", 0, "unbalanced: too many closes"),
        ("", 1, "empty string"),  # Edge case
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_str, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} - '{input_str}'")
        
        try:
            length = len(input_str)
            
            if is_seq:
                # Sequential: set inputs and start
                dut.string_in.value = pack_string(input_str)
                dut.length.value = length
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for completion
                await wait_for_done(dut)
                
                # Read result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result signal undefined")
                result = int(dut.result.value)
            else:
                # Combinational: set inputs directly
                dut.string_in.value = pack_string(input_str)
                dut.length.value = length
                await Timer(50, units='ns')  # Settle time
                
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result signal undefined")
                result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: Result = {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Small delay between tests
        if is_seq:
            await RisingEdge(dut.clk)
    
    # Final summary
    cocotb.log.info(f"\nTest Summary: {passed}/{len(test_cases)} passed")
    if failed > 0:
        raise TestFailure(f"{failed} tests failed out of {len(test_cases)}")