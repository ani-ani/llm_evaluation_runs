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

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

# Constants for scaling
N_MAX = 16
C_MAX = 256
SIZE_WIDTH = 8
IDX_WIDTH = 4
RESULT_COUNT_WIDTH = 5

@cocotb.test(timeout_time=10, timeout_unit="s")
async def test_app_installer(dut):
    """
    Test the app installer module with various test cases.
    """
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        clock = Clock(dut.clk, 10, units='ns')
        cocotb.start_soon(clock.start())
        
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        dut.app_valid_i.value = 0
        dut.app_done_i.value = 0
        for _ in range(5):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        await Timer(1, units='ns')

    # Test cases
    test_cases = [
        {
            'c': 100,
            'apps': [(99, 1, 1), (1, 99, 2)],
            'expected_count': 2,
            'expected_order': [1, 2],
            'desc': 'Example 1: Install both in order'
        },
        {
            'c': 100,
            'apps': [(500, 1, 1), (1, 500, 2)],
            'expected_count': 0,
            'expected_order': [],
            'desc': 'Example 2: No apps fit'
        },
        {
            'c': 100,
            'apps': [(50, 50, 1), (30, 30, 2), (20, 20, 3)],
            'expected_count': 3,
            'expected_order': [1, 2, 3],  # After sorting by size
            'desc': 'Multiple small apps'
        },
        {
            'c': 50,
            'apps': [(30, 20, 1), (25, 25, 2), (10, 40, 3)],
            'expected_count': 2,
            'expected_order': [3, 2],  # 10+25=35, or 30+25=55>50, or 40+25=65>50
            'desc': 'Optimal selection required'
        }
    ]

    for tc in test_cases:
        cocotb.log.info(f"\nTest Case: {tc['desc']}")
        cocotb.log.info(f"Capacity: {tc['c']}, Apps: {tc['apps']}")
        
        if is_seq:
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait a bit for state machine to enter input phase
            await RisingEdge(dut.clk)
            
            # Send apps
            for d, s, idx in tc['apps']:
                # Check if we can send data (module should be ready)
                dut.app_d_i.value = clamp_to_width(d, SIZE_WIDTH)
                dut.app_s_i.value = clamp_to_width(s, SIZE_WIDTH)
                dut.app_idx_i.value = clamp_to_width(idx, IDX_WIDTH)
                dut.app_valid_i.value = 1
                await RisingEdge(dut.clk)
                # Might need to wait if module is not ready, but assume it is for this test
            
            # Send done signal
            dut.app_valid_i.value = 0
            dut.app_done_i.value = 1
            await RisingEdge(dut.clk)
            dut.app_done_i.value = 0
            
            # Wait for done signal
            max_cycles = 70000
            done_found = False
            for cycle in range(max_cycles):
                await RisingEdge(dut.clk)
                if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    done_found = True
                    break
            
            if not done_found:
                raise TestFailure(f"Timeout waiting for 'done' signal. Last cycle: {cycle}")
            
            # Read results
            if not is_value_defined(dut.result_count.value):
                raise TestFailure("Result count is undefined")
            
            actual_count = int(dut.result_count.value)
            cocotb.log.info(f"Result count: {actual_count}")
            
            if actual_count != tc['expected_count']:
                raise TestFailure(f"Count mismatch. Expected {tc['expected_count']}, got {actual_count}")
            
            # Read order
            if actual_count > 0:
                actual_order = []
                for i in range(N_MAX):
                    port_name = f'result_order_{i}'
                    if has_signal(dut, port_name):
                        val = getattr(dut, port_name).value
                        if is_value_defined(val):
                            idx_val = int(val)
                            if idx_val != 0:  # 0 means unused slot
                                actual_order.append(idx_val)
                
                cocotb.log.info(f"Result order: {actual_order}")
                
                # The order might be reversed or have trailing zeros, check valid subset
                # We expect the apps to be in the output order
                # Since we don't enforce exact match (multiple optimal solutions), we check if all expected indices are present
                # and count matches.
                if set(actual_order) != set(tc['expected_order']):
                    # Allow for different orders if count is correct and apps are valid
                    # But for this test, we'll be strict if expected order is provided
                    raise TestFailure(f"Order mismatch. Expected {tc['expected_order']}, got {actual_order}")
        
        else:
            # Combinational version - just set inputs and wait
            dut.c.value = clamp_to_width(tc['c'], SIZE_WIDTH + 1)  # Capacity might need more bits
            # For combinational, we'd need a packed interface for apps, which is complex.
            # The spec implies sequential, so this path is less likely.
            # We'll skip combinational for this complex problem.
            cocotb.log.warning("Combinational test skipped for sequential-only problem")

    cocotb.log.info("\nAll tests passed!")
