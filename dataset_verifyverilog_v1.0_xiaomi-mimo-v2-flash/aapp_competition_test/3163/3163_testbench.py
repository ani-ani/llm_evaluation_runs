import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def write_shelf(dut, shelf_idx, arr, width, prefix='init'):
    """Write a single shelf's array to HDL"""
    for i, v in enumerate(arr):
        signal_name = f"{prefix}_arr_{shelf_idx}_{i}"
        if hasattr(dut, signal_name):
            getattr(dut, signal_name).value = clamp_to_width(v, width)

def pack_shelf(arr, width=8):
    """Pack shelf array into a single integer for combinational access if needed"""
    result = 0
    for i, v in enumerate(arr):
        result |= (v & ((1 << width) - 1)) << (i * width)
    return result

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_librarian(dut):
    # Parameters
    CLK_NS = 10
    MAX_SHELVES = 16
    MAX_SLOTS = 16
    DATA_WIDTH = 8
    
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Test cases: (init, target, expected_lifts, is_impossible)
    # Using scaled versions of examples
    test_cases = [
        (
            [
                [1, 0, 2, 0],
                [3, 5, 4, 0]
            ],
            [
                [2, 1, 0, 0],
                [3, 0, 4, 5]
            ],
            2, False  # Example 1: books 1,2,4,5 need moves? Actually check logic
        ),
        (
            [
                [1, 2, 3, 0],
                [4, 5, 6, 0],
                [7, 8, 0, 0]
            ],
            [
                [4, 2, 3, 0],
                [6, 5, 1, 0],
                [0, 7, 8, 0]
            ],
            4, False  # Example 2
        ),
        (
            [
                [1, 2, 0, 0],
                [3, 4, 0, 0]
            ],
            [
                [2, 3, 0, 0],
                [4, 1, 0, 0]
            ],
            4, False  # Example 3 (impossible? But logic says 4 lifts)
        )
    ]
    
    passed = 0
    failed = 0
    
    for t_idx, (init, target, expected, impossible) in enumerate(test_cases):
        cocotb.log.info(f"Test {t_idx+1}")
        
        # Scale to 16 shelves, 16 slots
        N = len(init)
        M = len(init[0]) if N > 0 else 0
        
        # Pad arrays to 16x16
        init_full = [[0]*16 for _ in range(16)]
        target_full = [[0]*16 for _ in range(16)]
        for i in range(N):
            for j in range(M):
                init_full[i][j] = init[i][j]
                target_full[i][j] = target[i][j]
        
        # Write inputs
        dut.N.value = N
        dut.M.value = M
        
        for i in range(16):
            for j in range(16):
                # Init array
                init_sig_name = f"init_arr_{i}_{j}"
                if hasattr(dut, init_sig_name):
                    getattr(dut, init_sig_name).value = clamp_to_width(init_full[i][j], DATA_WIDTH)
                
                # Target array
                target_sig_name = f"target_arr_{i}_{j}"
                if hasattr(dut, target_sig_name):
                    getattr(dut, target_sig_name).value = clamp_to_width(target_full[i][j], DATA_WIDTH)
        
        # Compute expected logically for comparison
        # Count total books in init
        total_books = 0
        correct_books = 0
        books_in_init = set()
        books_in_target = set()
        
        for i in range(N):
            for j in range(M):
                val_init = init[i][j]
                val_target = target[i][j]
                if val_init != 0:
                    total_books += 1
                    books_in_init.add(val_init)
                if val_target != 0:
                    books_in_target.add(val_target)
                if val_init != 0 and val_init == val_target:
                    correct_books += 1
        
        if books_in_init != books_in_target:
            # Impossible
            expected = -1
            is_impossible = True
        else:
            is_impossible = False
            expected = total_books - correct_books
        
        if is_seq:
            # Pulse start
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
            else:
                # If no start, assume combinational or wait
                await Timer(100, units='ns')
            
            # Wait for done if exists
            if has_signal(dut, 'done'):
                done_found = False
                for _ in range(1000):
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        done_found = True
                        break
                if not done_found:
                    cocotb.log.error(f"Test {t_idx+1}: Timeout waiting for done")
                    failed += 1
                    continue
            else:
                await Timer(100, units='ns')
        else:
            # Combinational
            await Timer(100, units='ns')
        
        # Read result
        result = 0
        error = 0
        
        if has_signal(dut, 'result'):
            if is_value_defined(dut.result.value):
                result = int(dut.result.value)
            else:
                cocotb.log.error(f"Test {t_idx+1}: Result undefined")
                failed += 1
                continue
        
        if has_signal(dut, 'error'):
            if is_value_defined(dut.error.value):
                error = int(dut.error.value)
            else:
                error = 0
        
        # Check
        if is_impossible:
            if error != 1:
                cocotb.log.error(f"Test {t_idx+1}: Expected error flag, got error={error}")
                failed += 1
            else:
                passed += 1
        else:
            if error == 1:
                cocotb.log.error(f"Test {t_idx+1}: Unexpected error flag")
                failed += 1
            elif result != expected:
                cocotb.log.error(f"Test {t_idx+1}: Expected {expected}, got {result}")
                failed += 1
            else:
                passed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
    else:
        cocotb.log.info(f"All {passed} tests passed")