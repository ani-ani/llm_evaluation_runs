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

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Test constants
DATA_WIDTH = 16
SHIFT_WIDTH = 4
CLK_NS = 10
MAX_CYCLES = 100

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_circular_shift(dut):
    """Test the circular_shift module"""
    
    # Start clock if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        
    # Reset
    if is_seq:
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        for _ in range(2): await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        # Combinational module
        dut.rst_n.value = 1
        await Timer(10, units='ns')

    # Test cases adapted for 4-digit representation
    # (x, shift, expected result)
    test_cases = [
        (12, 1, 21),     # 0012 -> shift 1 -> 2001 -> 2001 (Wait, logic check)
        # Let's trace: 0012, digits [0,0,1,2]. Right shift 1: [2,0,0,1] -> 2001
        # But Python circular_shift(12, 1) returns "21"
        # Python behavior: Extracts digits [1,2], right shift 1 -> [2,1] -> "21"
        # Hardware adaptation: Treat as 4 digits. "12" -> [0,0,1,2].
        # Right shift 1 -> [2,0,0,1] -> 2001.
        # This differs from Python's dynamic digit count.
        # Let's stick to the prompt's simplified rule: Pad to 4 digits.
        
        (12, 1, 2001),  # 0012 -> circular right shift 1 -> 2001
        (12, 2, 1002),  # 0012 -> circular right shift 2 -> 1002
        (12, 4, 12),    # Modulo 4, 0 shift
        (123, 1, 312),  # 0123 -> 3012 -> 3012 (Wait, 3012)
        # 0123 digits [0,1,2,3]. Right 1 -> [3,0,1,2] -> 3012
        (97, 8, 79),    # 0097 -> 8 % 4 = 0? No, 8 % 4 = 0. Wait.
        # Python: 97 -> 79. 97 -> "97". Shift 8. "79". 
        # Python logic: If shift > digits, reverse? No, "If shift > number of digits, return digits reversed."
        # Wait, the docstring says: "If shift > number of digits, return digits reversed."
        # Example: circular_shift(97, 8). Digits: [9,7]. Count=2. 8 > 2. Reverse -> "79".
        # This logic is specific.
        # Hardware adaptation:
        # 1. Extract digits (up to 4).
        # 2. Count digits N (ignoring leading zeros).
        # 3. If shift > N, reverse digits. (This is tricky in HW with fixed width).
        # Let's simplify for hardware: Use fixed 4 digits.
        # If shift % 4 == 0, return x.
        # If shift % 4 != 0, circular shift.
        # The "reverse" rule is a specific Python behavior for small numbers.
        # For benchmarking, we will implement the *core* circular shift logic.
        # We will ignore the "reverse if shift > digits" rule to keep it HW-friendly (fixed shifts).
        # OR we can implement the full logic.
        # Let's try to implement full logic but scaled.
        
        # Re-evaluating cases based on prompt "Fixed 4-digit array"
        (100, 2, 100),  # 0100 -> Shift 2 -> 0010 -> 10. Wait. 0100 digits [0,1,0,0].
        # Shift 2: [0,0,0,1] -> 1. (But Python expects "001" -> 1)
        # Python: circular_shift(100, 2) -> "001". 
        # 100 -> "100". Shift 2 -> "001". 
        # Hardware: 0100 -> 0001 (1). 
        # Let's adjust hardware logic to match Python's output as integer.
        # Python outputs STRING. We output INT.
        # Python "001" -> Int 1.
        # So (100, 2) -> 1.
        # Wait, Python test case: `assert candidate(100, 2) == "001"`
        # The result is a string "001".
        # If we return int, 001 is 1.
        # But strictly speaking, `int("001") == 1`.
        # The test cases in `check` compare strings.
        # Since we return integer, we must match the numeric value of the string.
        # "001" -> 1
        # "12" -> 12
        # "79" -> 79
        # "21" -> 21
        # "11" -> 11
        
        (100, 2, 1),    # 0100 -> 0001 -> 1
        (12, 2, 12),    # 0012 -> 0012 -> 12
        (97, 8, 79),    # 0097. Python: shift 8 > 2 digits -> reverse -> 79.
        # Hardware logic check: 
        # Extract digits of 97 -> [9,7]. N=2.
        # Shift 8 > 2. Logic: Reverse digits -> [7,9] -> 79.
        # This is complex to implement in Verilog (variable digit count extraction).
        # Let's simplify: We will ignore the "reverse if shift > digits" rule and just do circular shift modulo 4.
        # For 97 (0097), shift 8 -> 8 % 4 = 0. Result 97. 
        # But the test case expects 79. 
        # To make it pass, we must implement the digit extraction.
        # Let's implement the logic: Extract digits (determine N). 
        # If shift % N == 0 (or shift > N and reverse logic), handle.
        # Actually, the prompt says "If shift > number of digits, return digits reversed."
        # This is a specific behavior.
        # Let's implement a simplified version: 
        # 1. Extract non-zero leading digits count N.
        # 2. If shift > N: Reverse digits.
        # 3. Else: Circular shift by shift.
        
        (12, 101, 12),  # Shift 101. N=2. 101 > 2. Reverse? No, Python: 11. Wait.
        # circular_shift(11, 101) -> "11".
        # N=2. 101 > 2. Reverse "11" -> "11".
        (12, 1, 21),    # N=2. Shift 1 <= 2. Circular shift 1: 21.
    ]

    passed = 0
    failed = 0

    for i, (x_val, s_val, exp_val) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: x={x_val}, shift={s_val}")
        try:
            # Inputs
            dut.x.value = clamp_to_width(x_val, DATA_WIDTH)
            dut.shift.value = clamp_to_width(s_val, SHIFT_WIDTH)
            
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                found_done = False
                for _ in range(MAX_CYCLES):
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        found_done = True
                        break
                if not found_done:
                    raise TestFailure(f"Timeout waiting for done")
            else:
                await Timer(20, units='ns') # Propagation delay

            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            if result != exp_val:
                raise TestFailure(f"Expected {exp_val}, got {result}")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL (Case {i+1}): {e}")
            failed += 1

    if failed > 0:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
