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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'char_valid'): dut.char_valid.value = 0
    if has_signal(dut, 'last_char'): dut.last_char.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def send_string(dut, s):
    """Send string character by character"""
    for char in s:
        dut.char_in.value = ord(char)
        dut.char_valid.value = 1
        await RisingEdge(dut.clk)
        dut.char_valid.value = 0
        await RisingEdge(dut.clk)  # Inter-char gap
    # Signal end
    dut.last_char.value = 1
    await RisingEdge(dut.clk)
    dut.last_char.value = 0

async def wait_for_done(dut, max_cycles=200):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_meow_factor(dut):
    # Setup clock
    clk_period = 10  # ns
    cocotb.start_soon(Clock(dut.clk, clk_period, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (input_string, expected_result)
    test_cases = [
        ("pastimeofwhimsy", 1),
        ("yarn", 4),
        ("meow", 0),
        ("meo", 1),  # Need to insert 'w'
        ("mew", 1),  # Replace 'w' with 'o'
        ("mow", 1),  # Insert 'e'
        ("eow", 1),  # Insert 'm'
        ("moew", 1), # Swap adjacent (e and w) -> "mowe" not meow, wait. "moew" swap 3-4 -> "mowe". Not meow. 
        # Ops: Insert 'm' at start -> "meow"? No. "moew" -> replace 'e' with 'o'? No.
        # Let's test simple ones.
        ("abc", 4), # Insert 4 chars or delete 3 insert 4. Optimized: insert 4.
        ("meowmeow", 0),
    ]
    
    passed = 0
    failed = 0
    
    for i, (inp_str, exp_res) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: Input '{inp_str}', Expected {exp_res}")
        
        try:
            # Send input
            await send_string(dut, inp_str)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            
            if result != exp_res:
                raise TestFailure(f"Expected {exp_res}, got {result}")
            
            passed += 1
            
            # Reset for next test
            await reset_dut(dut)
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL (Case {i+1}): {e}")
            failed += 1
            # Reset to try next
            await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")