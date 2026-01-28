import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers from template
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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'clk'):
        for _ in range(cycles): await RisingEdge(dut.clk)
    else:
        await Timer(10, units='ns')
    dut.rst_n.value = 1
    if has_signal(dut, 'clk'):
        await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(10, units='ns')
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_set_left_most_unset_bit(dut):
    CLK_NS = 10
    DATA_WIDTH = 8
    
    # Setup clock if present
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational: just set inputs and check outputs
        await Timer(10, units='ns')
    
    # Test cases based on Python function
    # n=10 (0b00001010) -> 14 (0b00001110)
    # n=12 (0b00001100) -> 14 (0b00001110)
    # n=15 (0b00001111) -> 15 (0b00001111)
    test_cases = [
        (10, 14, "n=10 (binary 1010) -> set bit 3"),
        (12, 14, "n=12 (binary 1100) -> set bit 1"),
        (15, 15, "n=15 (binary 1111) -> all bits set"),
        (0, 1, "n=0 (binary 0000) -> set bit 7"),
        (1, 2, "n=1 (binary 0001) -> set bit 6"),
        (3, 4, "n=3 (binary 0011) -> set bit 5"),
        (7, 8, "n=7 (binary 0111) -> set bit 4"),
        (254, 254, "n=254 (binary 11111110) -> set bit 0"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n_val, exp_result, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            n_val_clamped = clamp_to_width(n_val, DATA_WIDTH)
            exp_result_clamped = clamp_to_width(exp_result, DATA_WIDTH)
            
            # Set inputs
            if has_signal(dut, 'n_in'):
                dut.n_in.value = n_val_clamped
            elif has_signal(dut, 'arr'):
                # If interface uses array
                dut.arr.value = n_val_clamped
            else:
                # Generic data input
                for bit in range(DATA_WIDTH):
                    bit_val = (n_val_clamped >> bit) & 1
                    if has_signal(dut, f'data_{bit}'):
                        getattr(dut, f'data_{bit}').value = bit_val
                    elif has_signal(dut, f'data'):
                        dut.data.value = n_val_clamped
            
            if is_seq:
                # Pulse start
                if has_signal(dut, 'start'):
                    dut.start.value = 1
                    await RisingEdge(dut.clk)
                    dut.start.value = 0
                else:
                    await RisingEdge(dut.clk)
                
                # Wait for done
                if has_signal(dut, 'done'):
                    await wait_for_done(dut, max_cycles=20)
                else:
                    await Timer(100, units='ns')
            else:
                # Combinational: wait for propagation
                await Timer(10, units='ns')
            
            # Read result
            if has_signal(dut, 'result'):
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result signal undefined")
                result_val = int(dut.result.value)
            elif has_signal(dut, 'y'):
                if not is_value_defined(dut.y.value):
                    raise TestFailure("Result signal undefined")
                result_val = int(dut.y.value)
            else:
                raise TestFailure("No result signal found")
            
            # Compare
            if result_val != exp_result_clamped:
                raise TestFailure(f"Expected {exp_result_clamped}, got {result_val}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL Test {i+1}: {e}")
            failed += 1
        
        # Small delay between tests
        await Timer(10, units='ns')
    
    if failed:
        raise TestFailure(f"{failed} out of {passed+failed} tests failed")