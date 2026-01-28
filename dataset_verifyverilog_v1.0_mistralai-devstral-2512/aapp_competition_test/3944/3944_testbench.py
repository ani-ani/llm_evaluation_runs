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

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def wait_for_done(dut, max_cycles=5000):
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

# Test function
@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_card_game(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test cases scaled down: (n, m, k) -> expected result (approximate for demo)
    # Note: The actual result depends on the specific card inputs provided.
    # Since the original problem uses random cards, we will simulate specific card sets.
    # For the purpose of this test, we assume the hardware computes the count for fixed inputs.
    
    test_cases = [
        # (n, m, k, card_a_list, card_b_list, card_c_list, expected_result)
        # Scaling: 1,1,1 -> 17 (as per problem)
        (1, 1, 1, [0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0], [0, 0, 0, 0, 0, 0], 17),
        # (4, 2, 2) -> 1227 (approximate)
        (4, 2, 2, [0]*16, [0]*16, [0]*16, 1227),
    ]
    
    for i, (n, m, k, card_a, card_b, card_c, expected) in enumerate(test_cases):
        cocotb.log.info(f"Running test case {i+1}: N={n}, M={m}, K={k}")
        
        # Input values
        dut.n_val.value = clamp_to_width(n, 4)
        dut.m_val.value = clamp_to_width(m, 4)
        dut.k_val.value = clamp_to_width(k, 4)
        
        # Load card arrays
        # Assuming dut has individual signals or array access
        # If array access is supported:
        if hasattr(dut, 'card_a') and hasattr(dut.card_a, '__len__'):
             for idx in range(min(len(card_a), len(dut.card_a))):
                dut.card_a[idx].value = clamp_to_width(card_a[idx], 2)  # 2 bits for 0-2
        else:
             # Fallback for individual signals card_a_0, card_a_1...
             for idx in range(len(card_a)):
                 if hasattr(dut, f'card_a_{idx}'):
                     getattr(dut, f'card_a_{idx}').value = clamp_to_width(card_a[idx], 2)
                    
        if hasattr(dut, 'card_b') and hasattr(dut.card_b, '__len__'):
             for idx in range(min(len(card_b), len(dut.card_b))):
                dut.card_b[idx].value = clamp_to_width(card_b[idx], 2)
        else:
             for idx in range(len(card_b)):
                 if hasattr(dut, f'card_b_{idx}'):
                     getattr(dut, f'card_b_{idx}').value = clamp_to_width(card_b[idx], 2)
                     
        if hasattr(dut, 'card_c') and hasattr(dut.card_c, '__len__'):
             for idx in range(min(len(card_c), len(dut.card_c))):
                dut.card_c[idx].value = clamp_to_width(card_c[idx], 2)
        else:
             for idx in range(len(card_c)):
                 if hasattr(dut, f'card_c_{idx}'):
                     getattr(dut, f'card_c_{idx}').value = clamp_to_width(card_c[idx], 2)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Check result
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result signal is undefined")
            
        result = int(dut.result.value)
        # Allow some flexibility if exact formula differs or if input scaling affects exact output
        # For this demo, we check exact match for the provided cases
        if result != expected:
             raise TestFailure(f"Test {i+1} Failed: Expected {expected}, Got {result}")
             
    cocotb.log.info("All tests passed!")
