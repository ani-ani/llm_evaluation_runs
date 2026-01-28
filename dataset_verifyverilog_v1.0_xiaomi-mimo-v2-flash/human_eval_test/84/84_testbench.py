import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

def to_binary_string(value, bits=8):
    """Convert integer to binary string (MSB-first)"""
    return format(value & ((1 << bits) - 1), f'0{bits}b')

def digit_sum_binary_py(N):
    """Python reference implementation"""
    if N == 0:
        return 0
    total = 0
    while N > 0:
        total += N % 10
        N //= 10
    return total

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_digit_sum_binary(dut):
    # Setup clock
    CLK_NS = 10
    MAX_CYCLES = 256
    
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
    
    test_cases = [
        (1000, "1", "sum=1"),
        (150, "110", "sum=6"),
        (147, "1100", "sum=12"),
        (333, "1001", "sum=9"),
        (963, "10010", "sum=18"),
        (0, "0", "edge: zero"),
        (9999, "110111", "max digits"),
        (12345, "15->1111", "5 digits"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n_in, exp_bin, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: N={n_in} ({desc})")
        
        try:
            # Expected computation
            expected_sum = digit_sum_binary_py(n_in)
            expected_bits = to_binary_string(expected_sum, 8)
            
            # Convert decimal string to binary for comparison
            if isinstance(exp_bin, str) and '->' in exp_bin:
                # Format: "sum->binary"
                exp_bits = exp_bin.split('->')[1]
            else:
                exp_bits = exp_bin
            
            # Pad expected to 8 bits for comparison
            exp_bits = exp_bits.zfill(8)
            
            if has_signal(dut, 'n_in'):
                dut.n_in.value = clamp_to_width(n_in, 14)
            elif has_signal(dut, 'n'):  # Alternative port name
                dut.n.value = clamp_to_width(n_in, 14)
            elif has_signal(dut, 'N'):  # Uppercase
                dut.N.value = clamp_to_width(n_in, 14)
            
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
            
            # Wait for done signal
            if has_signal(dut, 'done'):
                for _ in range(MAX_CYCLES):
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        break
                else:
                    raise TestFailure(f"Timeout after {MAX_CYCLES} cycles")
                
                # Read result
                if is_value_defined(dut.result.value):
                    result_val = int(dut.result.value)
                    result_bin = to_binary_string(result_val, 8)
                    
                    cocotb.log.info(f"  Expected: {exp_bits} (sum={expected_sum})")
                    cocotb.log.info(f"  Got:      {result_bin}")
                    
                    if result_bin != exp_bits:
                        raise TestFailure(f"Binary mismatch: expected {exp_bits}, got {result_bin}")
                else:
                    raise TestFailure("Result signal undefined")
            else:
                # Combinational or different interface
                await Timer(100, units='ns')
                if is_value_defined(dut.result.value):
                    result_val = int(dut.result.value)
                    result_bin = to_binary_string(result_val, 8)
                    if result_bin != exp_bits:
                        raise TestFailure(f"Expected {exp_bits}, got {result_bin}")
                else:
                    raise TestFailure("Result undefined")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} test(s) failed, {passed} passed")
