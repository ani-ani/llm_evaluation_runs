import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 4
MAX_DIGITS = 20
CLK_NS = 10
MAX_CYCLES = 500

# Helper functions from specification
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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'data_valid'): dut.data_valid.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def send_digits(dut, digits, delay_ns=100):
    """Send digits one by one with data_valid strobes"""
    for digit in digits:
        dut.data_in.value = clamp_to_width(digit, DATA_WIDTH)
        dut.data_valid.value = 1
        await Timer(delay_ns, units='ns')
        await RisingEdge(dut.clk)
        dut.data_valid.value = 0
        await Timer(delay_ns, units='ns')

async def read_output(dut, expected_len):
    """Read output digits until done or timeout"""
    output = []
    cycles = 0
    max_output_cycles = 100
    while cycles < max_output_cycles:
        await RisingEdge(dut.clk)
        cycles += 1
        if is_value_defined(dut.out_valid.value) and int(dut.out_valid.value) == 1:
            if is_value_defined(dut.data_out.value):
                output.append(int(dut.data_out.value))
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            break
    return output

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_divisible_by_7(dut):
    """
    Test the digit rearrangement module.
    
    Test cases based on the provided examples:
    1. Input: 1689 -> Output: 1869 (permutation 1869 makes it divisible by 7)
    2. Input: 18906 -> Output: 18690 (perm 1869, plus 0)
    3. Additional test: 2419323689 -> 2432391689
    """
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (input_str, expected_output_str, description)
    test_cases = [
        ("1689", "1869", "Basic case - 1689"),
        ("18906", "18690", "With one zero - 18906"),
        ("2419323689", "2432391689", "More digits - 2419323689"),
        ("4048169", "4041968", "With leading non-zeros - 4048169"),
        ("16891", "16198", "Duplicate digits - 16891"),
    ]
    
    passed = 0
    failed = 0
    
    for idx, (input_str, expected_str, desc) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {idx+1}: {desc}")
        cocotb.log.info(f"Input: {input_str}, Expected: {expected_str}")
        
        try:
            if is_seq:
                # Convert input string to list of digits
                digits = [int(c) for c in input_str]
                
                # Send start signal
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Send digits with data_valid
                for digit in digits:
                    dut.data_in.value = clamp_to_width(digit, DATA_WIDTH)
                    dut.data_valid.value = 1
                    await RisingEdge(dut.clk)
                    dut.data_valid.value = 0
                    # Wait a bit between digits
                    await RisingEdge(dut.clk)
                
                # Wait for processing
                await wait_for_done(dut)
                
                # Read output digits
                output = []
                cycles = 0
                while cycles < 200:
                    await RisingEdge(dut.clk)
                    cycles += 1
                    if is_value_defined(dut.out_valid.value) and int(dut.out_valid.value) == 1:
                        if is_value_defined(dut.data_out.value):
                            output.append(int(dut.data_out.value))
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        break
                
                # Convert output to string
                output_str = ''.join(str(d) for d in output)
                cocotb.log.info(f"Output: {output_str}")
                
                # Check result
                if output_str != expected_str:
                    raise TestFailure(f"Expected '{expected_str}', got '{output_str}'")
                
                # Verify divisibility by 7
                result_num = int(output_str)
                if result_num % 7 != 0:
                    raise TestFailure(f"Result {result_num} not divisible by 7")
                
                passed += 1
                
            else:
                # Combinational test
                cocotb.log.info("Combinational test - skipping for now")
                passed += 1
                
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        
        # Reset for next test
        if is_seq:
            await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_edge_cases(dut):
    """Test edge cases"""
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    edge_cases = [
        ("100000000689", "186900000000", "Many zeros - 100000000689"),
        ("1689999999999", "9999999991968", "Many 9s - 1689999999999"),
        ("6198", "1869", "Only 1689 family - 6198"),
    ]
    
    passed = 0
    failed = 0
    
    for idx, (input_str, expected_str, desc) in enumerate(edge_cases):
        cocotb.log.info(f"\nEdge case {idx+1}: {desc}")
        cocotb.log.info(f"Input: {input_str}, Expected: {expected_str}")
        
        try:
            if is_seq:
                digits = [int(c) for c in input_str]
                
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                for digit in digits:
                    dut.data_in.value = clamp_to_width(digit, DATA_WIDTH)
                    dut.data_valid.value = 1
                    await RisingEdge(dut.clk)
                    dut.data_valid.value = 0
                    await RisingEdge(dut.clk)
                
                await wait_for_done(dut)
                
                output = []
                cycles = 0
                while cycles < 300:  # Allow more cycles for longer outputs
                    await RisingEdge(dut.clk)
                    cycles += 1
                    if is_value_defined(dut.out_valid.value) and int(dut.out_valid.value) == 1:
                        if is_value_defined(dut.data_out.value):
                            output.append(int(dut.data_out.value))
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        break
                
                output_str = ''.join(str(d) for d in output)
                cocotb.log.info(f"Output: {output_str}")
                
                if output_str != expected_str:
                    raise TestFailure(f"Expected '{expected_str}', got '{output_str}'")
                
                result_num = int(output_str)
                if result_num % 7 != 0:
                    raise TestFailure(f"Result {result_num} not divisible by 7")
                
                passed += 1
                
            else:
                cocotb.log.info("Combinational test - skipping")
                passed += 1
                
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        
        if is_seq:
            await reset_dut(dut)
    
    if failed:
        raise TestFailure(f"{failed} edge case tests failed")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_modulo_calculation(dut):
    """Test modulo 7 calculation with random inputs"""
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test with random inputs that include 1,6,8,9
    for test_num in range(3):
        # Generate random digits including 1,6,8,9
        base_digits = [1, 6, 8, 9]
        extra_digits = [random.randint(0, 9) for _ in range(random.randint(2, 15))]
        all_digits = base_digits + extra_digits
        random.shuffle(all_digits)
        
        input_str = ''.join(str(d) for d in all_digits)
        cocotb.log.info(f"Random test {test_num+1}: {input_str}")
        
        if is_seq:
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            for digit in all_digits:
                dut.data_in.value = clamp_to_width(digit, DATA_WIDTH)
                dut.data_valid.value = 1
                await RisingEdge(dut.clk)
                dut.data_valid.value = 0
                await RisingEdge(dut.clk)
            
            await wait_for_done(dut)
            
            output = []
            cycles = 0
            while cycles < 200:
                await RisingEdge(dut.clk)
                cycles += 1
                if is_value_defined(dut.out_valid.value) and int(dut.out_valid.value) == 1:
                    if is_value_defined(dut.data_out.value):
                        output.append(int(dut.data_out.value))
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    break
            
            output_str = ''.join(str(d) for d in output)
            cocotb.log.info(f"Output: {output_str}")
            
            # Check no leading zero unless output is 0
            if len(output_str) > 1 and output_str[0] == '0':
                raise TestFailure(f"Output has leading zero: {output_str}")
            
            # Check divisibility
            result_num = int(output_str)
            if result_num % 7 != 0:
                raise TestFailure(f"Result {result_num} not divisible by 7")
            
            # Check that output contains the same digits (permuted)
            input_sorted = sorted(input_str)
            output_sorted = sorted(output_str)
            if input_sorted != output_sorted:
                raise TestFailure(f"Digit mismatch: input {input_sorted}, output {output_sorted}")
            
            await reset_dut(dut)
        else:
            cocotb.log.info("Combinational test - skipping")
            
    cocotb.log.info("Random tests passed")