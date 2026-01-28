import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=128):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Helper to calculate expected binary decomposition sum
def calculate_expected(n):
    # This mirrors the hardware logic for validation.
    # We simulate the instruction sequence.
    stack = []
    a = 0; x = 0; y = 0
    # Algorithm: Decompose N into binary representation bits.
    # For each bit set, push 1 and add appropriately.
    # Simplified generic sequence generation logic for testbench:
    if n == 0:
        return 0
    
    # We will simulate the minimal adder tree.
    # Since the hardware generates instructions, we simulate the result of those instructions.
    # The specific algorithm in hardware is: N is sum of powers of 2.
    # Implementation: 
    # 1. If N is power of 2 (e.g., 2, 4, 8...), we push 1 multiple times and add.
    # 2. For general N, we use binary decomposition.
    # 
    # The hardware FSM is expected to produce: ST A, ST X (if needed), etc.
    # Let's assume the hardware implements a simple loop: if bit is set, add 2^k.
    # To keep it simple for testing, we verify the output `result` matches `n_in`.
    return n

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_processor_calculation(dut):
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases
    test_values = [0, 1, 2, 3, 5, 7, 15, 31, 255]
    
    for n in test_values:
        cocotb.log.info(f"Testing N={n}")
        
        # Input value
        dut.n_in.value = n
        
        # Start signal
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut)
        
        # Check result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result undefined for N={n}")
        
        result = int(dut.result.value)
        
        # For N=0, the sequence should likely be ST A, DI A (result 1?) or ZE A, DI A (result 0?)
        # The problem statement says registers init to unknown values.
        # A robust solution for 0 should be: ZE A, DI A.
        # However, if the hardware handles 0 as a special case or simply generates a sequence summing to 0.
        # If the algorithm is binary summation, 0 might be tricky. 
        # Let's check if result equals n.
        
        if result != n:
            # Special handling for 0 if not implemented correctly in HW, but we assume it is.
            # If HW logic requires at least one instruction, result might differ.
            # But strictly, output must be N.
            if n == 0 and result == 1: # Common off-by-one if treating 0 as empty sum
                 cocotb.log.warning(f"N=0 returned 1, adjusting expectation if allowed (hardware quirk)")
                 # strictly should be 0. 
            raise TestFailure(f"Expected {n}, got {result}")
            
    cocotb.log.info("All tests passed!")
