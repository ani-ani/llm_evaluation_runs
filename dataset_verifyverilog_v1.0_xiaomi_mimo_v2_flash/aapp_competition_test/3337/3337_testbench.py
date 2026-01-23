import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import re

# ============================================================================
# CONFIGURATION
# ============================================================================
MAX_OPS = 16
MAX_STACK_SIZE = 8
DATA_WIDTH = 8
ADDR_WIDTH = 4
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    """Convert unsigned integer to signed (two's complement)."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    """Convert signed integer to unsigned for Verilog assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_stack(dut, stack_idx, values):
    """Write values to a specific stack."""
    # Write elements
    for i, val in enumerate(values):
        if i < MAX_STACK_SIZE:
            dut.stacks[stack_idx][i].value = clamp_to_width(val, DATA_WIDTH)
    # Write length
    dut.stack_len[stack_idx].value = len(values)

async def read_result(dut):
    """Read result signal with validation."""
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result is undefined (X/Z)")
    return int(dut.result.value)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    """Reset the DUT."""
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.op_type.value = 0
    dut.v.value = 0
    dut.w.value = 0
    
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_stack_operations(dut):
    """Test stack operations with scaled-down problem."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (operations, expected_outputs)
    # Operation format: (type, v, w, description)
    # Type: 'a'=push, 'b'=pop, 'c'=count
    test_cases = [
        {
            "name": "Basic push/pop/count",
            "operations": [
                ('a', 0, None, "Push 1 onto stack 0 -> create stack 1"),
                ('a', 1, None, "Push 2 onto stack 1 -> create stack 2"),
                ('b', 2, None, "Pop from stack 2 -> output 2"),
                ('c', 2, 3, "Count common in stacks 2 and 3 -> output 1"),
                ('b', 4, None, "Pop from stack 4 -> output 2"),
            ],
            "expected": [2, 1, 2]
        },
        {
            "name": "Complex sequence",
            "operations": [
                ('a', 0, None, "Push 1"),
                ('a', 1, None, "Push 2"),
                ('a', 2, None, "Push 3"),
                ('a', 3, None, "Push 4"),
                ('a', 2, None, "Push 5 onto stack 2 -> create stack 5"),
                ('c', 4, 5, "Count common 4 and 5"),
                ('a', 5, None, "Push 6"),
                ('a', 6, None, "Push 7"),
                ('c', 8, 7, "Count common 8 and 7"),
                ('b', 8, None, "Pop from 8"),
                ('b', 8, None, "Pop from 8"),
            ],
            "expected": [2, 2, 8, 8]
        }
    ]
    
    total_passed = 0
    total_failed = 0
    
    for test_case in test_cases:
        cocotb.log.info(f"\n{'='*60}")
        cocotb.log.info(f"Test: {test_case['name']}")
        cocotb.log.info(f"{'='*60}")
        
        # Reset again between test cases
        await reset_dut(dut)
        
        # Track expected outputs
        expected_outputs = test_case['expected']
        actual_outputs = []
        output_idx = 0
        
        # Process each operation
        for op_idx, (op_type, v, w, desc) in enumerate(test_case['operations']):
            cocotb.log.info(f"\nOperation {op_idx+1}: {desc}")
            
            # Map operation type
            if op_type == 'a':
                op_code = 0  # Push
                w_val = 0    # Not used
            elif op_type == 'b':
                op_code = 1  # Pop
                w_val = 0    # Not used
            elif op_type == 'c':
                op_code = 2  # Count
                w_val = w
            else:
                raise TestFailure(f"Unknown operation type: {op_type}")
            
            # Drive inputs
            dut.op_type.value = op_code
            dut.v.value = v
            if op_type == 'c':
                dut.w.value = w_val
            else:
                dut.w.value = 0
            
            # Start operation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for completion
            await wait_for_done(dut)
            
            # For pop and count operations, read and store result
            if op_type in ['b', 'c']:
                result = await read_result(dut)
                actual_outputs.append(result)
                cocotb.log.info(f"  Result: {result}")
                
                # Verify against expected
                if output_idx < len(expected_outputs):
                    expected = expected_outputs[output_idx]
                    if result != expected:
                        cocotb.log.error(f"  FAIL: Expected {expected}, got {result}")
                        total_failed += 1
                    else:
                        cocotb.log.info(f"  PASS: Got expected {expected}")
                        total_passed += 1
                else:
                    cocotb.log.error(f"  FAIL: Unexpected output (no expected value)")
                    total_failed += 1
                
                output_idx += 1
            else:
                cocotb.log.info(f"  Operation completed (no output)")
        
        # Verify all expected outputs were produced
        if output_idx != len(expected_outputs):
            cocotb.log.error(f"  FAIL: Expected {len(expected_outputs)} outputs, got {output_idx}")
            total_failed += len(expected_outputs) - output_idx
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"FINAL RESULTS: {total_passed} passed, {total_failed} failed")
    cocotb.log.info(f"{'='*60}")
    
    if total_failed > 0:
        raise TestFailure(f"{total_failed} tests failed")
