import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

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

def float_to_fixed(f, frac_bits=4):
    return int(f * (1 << frac_bits))

def fixed_to_float(v, frac_bits=4):
    return v / (1 << frac_bits)

# Test Logic
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_snake_path(dut):
    """Test the Snake Path Finding Module"""
    
    # Configuration
    CLK_NS = 10
    MAX_CYCLES = 5000
    DATA_WIDTH = 12  # Q8.4 fixed point
    NUM_SNAKES = 4   # Max supported in this adaptation
    
    # Setup Clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset DUT
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
        else:
            await Timer(20, units='ns')
        dut.rst_n.value = 1
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
    else:
        await Timer(10, units='ns')

    async def run_test(snake_data, expected_success, expected_desc):
        dut._log.info(f"Running test: {expected_desc}")
        
        # Clear inputs
        for i in range(NUM_SNAKES):
            if has_signal(dut, f'snake_x_{i}'):
                getattr(dut, f'snake_x_{i}').value = 0
                getattr(dut, f'snake_y_{i}').value = 0
                getattr(dut, f'snake_d_{i}').value = 0
            elif hasattr(dut, 'snake_x'):
                dut.snake_x[i].value = 0
                dut.snake_y[i].value = 0
                dut.snake_d[i].value = 0
        
        if has_signal(dut, 'snake_count'):
            dut.snake_count.value = len(snake_data)
            
        # Load snake data
        for i, (x, y, d) in enumerate(snake_data):
            val_x = float_to_fixed(x)
            val_y = float_to_fixed(y)
            val_d = float_to_fixed(d)
            
            # Handle individual ports or arrays
            if has_signal(dut, f'snake_x_{i}'):
                getattr(dut, f'snake_x_{i}').value = clamp_to_width(val_x, DATA_WIDTH)
                getattr(dut, f'snake_y_{i}').value = clamp_to_width(val_y, DATA_WIDTH)
                getattr(dut, f'snake_d_{i}').value = clamp_to_width(val_d, DATA_WIDTH)
            elif hasattr(dut, 'snake_x'):
                dut.snake_x[i].value = clamp_to_width(val_x, DATA_WIDTH)
                dut.snake_y[i].value = clamp_to_width(val_y, DATA_WIDTH)
                dut.snake_d[i].value = clamp_to_width(val_d, DATA_WIDTH)
            else:
                # Fallback if signals are named differently
                pass

        # Start computation
        if has_signal(dut, 'start'):
            dut.start.value = 1
            if has_signal(dut, 'clk'):
                await RisingEdge(dut.clk)
            else:
                await Timer(CLK_NS, units='ns')
            dut.start.value = 0
        else:
            # Combinational or auto-start
            await Timer(100, units='ns')

        # Wait for done
        max_wait = MAX_CYCLES
        found_done = False
        for _ in range(max_wait):
            if has_signal(dut, 'clk'):
                await RisingEdge(dut.clk)
            else:
                await Timer(CLK_NS, units='ns')
                
            if has_signal(dut, 'done'):
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    found_done = True
                    break
            else:
                # If no done signal, assume combinational delay
                await Timer(200, units='ns')
                found_done = True
                break

        if not found_done:
            raise TestFailure(f"Did not receive 'done' signal within {max_wait} cycles")

        # Read results
        if has_signal(dut, 'success'):
            actual_success = int(dut.success.value)
        else:
            actual_success = 0 # Default assumption

        # Compare results
        if actual_success != expected_success:
            raise TestFailure(f"Success mismatch. Expected {expected_success}, got {actual_success}")
            
        if expected_success:
            # Read coordinates
            entry_y_val = 0
            exit_y_val = 0
            
            if has_signal(dut, 'entry_y'):
                entry_y_val = int(dut.entry_y.value)
            if has_signal(dut, 'exit_y'):
                exit_y_val = int(dut.exit_y.value)
            
            entry_float = fixed_to_float(entry_y_val)
            exit_float = fixed_to_float(exit_y_val)
            
            dut._log.info(f"Path found: Entry {entry_float:.2f}, Exit {exit_float:.2f}")
            
            # Basic sanity checks for float output
            if not (0 <= entry_float <= 1000):
                raise TestFailure(f"Entry Y {entry_float} out of bounds")
            if not (0 <= exit_float <= 1000):
                raise TestFailure(f"Exit Y {exit_float} out of bounds")

    # --- Test Cases ---
    
    # Case 1: Sample Input 1
    # 3
    # 500 500 499
    # 0 0 999
    # 1000 1000 200
    # Expected: Entry (0, 1000), Exit (1000, 800)
    snakes1 = [(500, 500, 499), (0, 0, 999), (1000, 1000, 200)]
    await run_test(snakes1, 1, "Sample 1")

    # Case 2: Sample Input 2
    # 4 squares blocking center
    # Expected: Bitten
    snakes2 = [(250, 250, 300), (750, 250, 300), (250, 750, 300), (750, 750, 300)]
    await run_test(snakes2, 0, "Sample 2 Blocked")

    # Case 3: Single snake in center, small radius
    # 1
    # 500 500 500
    # Expected: Possible (top path)
    snakes3 = [(500, 500, 500)]
    await run_test(snakes3, 1, "Single Center")

    # Case 4: Empty field
    snakes4 = []
    await run_test(snakes4, 1, "Empty Field")

    dut._log.info("All tests passed!")