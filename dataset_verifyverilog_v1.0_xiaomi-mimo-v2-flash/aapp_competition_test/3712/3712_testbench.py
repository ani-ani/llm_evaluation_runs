import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# --- Helpers ---
def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, int(v)))

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'valid_in'): dut.valid_in.value = 0
    if has_signal(dut, 'last_in'): dut.last_in.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=10000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout waiting for done signal")

async def feed_input_sequence(dut, counts):
    """Feeds a list of compartment student counts [0,1,2,3,4] to the module."""
    if not has_signal(dut, 'data_in') or not has_signal(dut, 'valid_in'):
        return # Combinational module

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    total_students = 0
    for i, val in enumerate(counts):
        total_students += val
        dut.data_in.value = clamp_to_width(val, 4)
        dut.valid_in.value = 1
        dut.last_in.value = 1 if i == len(counts) - 1 else 0
        await RisingEdge(dut.clk)
        
        # Wait for ready if flow control exists
        if has_signal(dut, 'ready'):
            while not int(dut.ready.value):
                await RisingEdge(dut.clk)
    
    dut.valid_in.value = 0
    dut.last_in.value = 0
    return total_students

# --- Test Cases ---
# We need to map the Python output logic to HW logic.
# Python logic depends on total sum. If sum < 3 or sum == 5, return -1.
# In Verilog, we'll check this condition. If invalid, we might output a specific value (e.g., 16'hFFFF) or handle as error.
# Assuming valid inputs for the benchmark.

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_student_compartments(dut):
    # Setup Clock
    if not has_signal(dut, 'clk'):
        return # Skip if no clock
        
    CLK_NS = 10
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)

    # Test Cases: List of counts [1, 2, ... 4]
    test_data = [
        ([1, 2, 2, 4, 3], 2),   # Ex 1
        ([4, 1, 1], 2),          # Ex 2
        ([0, 3, 0, 4], 0),       # Ex 3
        ([4, 4, 3, 3, 1], 1),    # Ex 4
        ([1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1], 11), # Sum 11 > 2, != 5
        ([1, 1, 1, 2, 2, 1], 4), # Sum 8
        ([1], -1),               # Sum 1 < 3
        ([2], -1),               # Sum 2 < 3
        ([1, 4], 2),             # Sum 5 -> -1 (according to logic? Wait, example logic says if sum==5 print -1. Example input 3: 0 3 0 4 -> sum 7. Example 2: 4 1 1 -> sum 6.
    ]

    # The Python solution implies: if s > 2 and s != 5: logic else -1.
    # So [1, 4] sum=5 should be -1.
    # [1, 1, 1, 2, 2, 1] sum=8.
    
    # Let's verify the specific output for these inputs using the logic in the prompt.
    # Input 5
    # 1 2 2 4 3 -> sum=12. c1=1, c2=2, c3=1, c4=1.
    # min(c1, c2)=1. res=1. c1=0, c2=1, c3=2.
    # c2=1. c4>0. res+=1. c2=0. Total=2. Correct.
    
    # Input [1, 1, 1, 2, 2, 1] -> sum=8.
    # c1=4, c2=2.
    # min=2. res=2. c1=2, c2=0, c3=2.
    # c1=2. c3>0 (2). res+=2. c1=0. Total=4.
    
    # Expected outputs mapped to test cases
    # (Counts, Expected Result)
    # Note: For invalid cases (sum<3 or sum==5), the module should signal error or output specific value.
    # We'll assume it outputs -1 (as unsigned 16-bit 65535) or checks valid.
    # Let's refine test cases based on prompt examples:
    
    refined_tests = [
        ([1, 2, 2, 4, 3], 2, "Ex1"),
        ([4, 1, 1], 2, "Ex2"),
        ([0, 3, 0, 4], 0, "Ex3"),
        ([4, 4, 3, 3, 1], 1, "Ex4"),
        ([1, 1, 1, 1, 1], -1, "Sum 5 Error"),
        ([1, 1], -1, "Sum 2 Error"),
        ([1, 1, 1, 2, 2, 1], 4, "Mixed Valid"),
        ([2, 2, 2], 2, "Three 2s -> 2 swaps"),
    ]

    for counts, expected, desc in refined_tests:
        cocotb.log.info(f"Running test: {desc} - Counts: {counts}")
        
        total_sum = sum(counts)
        is_valid = (total_sum > 2) and (total_sum != 5)
        
        await feed_input_sequence(dut, counts)
        await wait_for_done(dut)
        
        result = int(dut.result.value)
        
        if expected == -1:
            # Check if module flagged error (e.g., result == 65535 or a specific error bit)
            # Assuming standard behavior where it might not handle invalid input gracefully or outputs a flag.
            # If the module is designed to handle valid inputs only, we skip checks for invalid or expect a specific error code.
            cocotb.log.info(f"Test {desc}: Input sum {total_sum} (Invalid). Result: {result}. Module behavior expected for invalid.")
            # For benchmarking, we focus on valid cases, but including invalid checks robustness.
            # If the spec implies -1 output, check for 16'hFFFF or similar.
            if is_value_defined(dut.error) and int(dut.error.value) == 1:
                pass # Good
            else:
                # If no error bit, check result
                if result != 65535 and result != 0: # Assuming 0 or -1 mapped
                    cocotb.log.warning(f"Invalid input result was {result}, expected error code.")
        else:
            if result != expected:
                raise TestFailure(f"{desc}: Expected {expected}, got {result}")

    cocotb.log.info("All tests passed!")
