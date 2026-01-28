import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# Global constants
CLK_NS = 10
MAX_CYCLES = 1000

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_decimal_to_binary(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        await Timer(100, units='ns')
    
    # Test cases: (input, expected_output_string)
    test_cases = [
        (0, "db0db" + " " * 11),
        (15, "db1111db" + " " * 8),
        (32, "db100000db" + " " * 6),
        (103, "db1100111db" + " " * 5),
        (255, "db11111111db" + " " * 4)
    ]
    
    passed = 0
    failed = 0
    
    for i, (decimal_input, expected_str) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: decimal_in={decimal_input}, expected='{expected_str}'")
        try:
            # Set input
            if has_signal(dut, 'decimal_in'):
                dut.decimal_in.value = clamp_to_width(decimal_input, 8)
            else:
                raise TestFailure("Signal decimal_in not found")
            
            if is_seq:
                # Start conversion
                if has_signal(dut, 'start'):
                    dut.start.value = 1
                    await RisingEdge(dut.clk)
                    dut.start.value = 0
                else:
                    raise TestFailure("Signal start not found")
                
                # Wait for done
                await wait_for_done(dut)
            else:
                await Timer(100, units='ns')
            
            # Check done and valid signals
            if is_seq:
                if has_signal(dut, 'done'):
                    done_val = int(dut.done.value)
                    if done_val != 1:
                        raise TestFailure(f"done not 1 after conversion, got {done_val}")
                
                if has_signal(dut, 'valid'):
                    valid_val = int(dut.valid.value)
                    if valid_val != 1:
                        raise TestFailure(f"valid not 1 after conversion, got {valid_val}")
            
            # Read binary_str array
            binary_str = []
            if has_signal(dut, 'binary_str'):
                # It's an array of 16 bytes
                for idx in range(16):
                    if hasattr(dut.binary_str, '__getitem__'):
                        char_val = dut.binary_str[idx].value
                        if is_value_defined(char_val):
                            char_int = int(char_val)
                            binary_str.append(chr(char_int))
                        else:
                            raise TestFailure(f"binary_str[{idx}] undefined")
                    else:
                        raise TestFailure("binary_str not indexable")
            else:
                # Check for individual ports like binary_str_0, binary_str_1...
                for idx in range(16):
                    port_name = f'binary_str_{idx}'
                    if has_signal(dut, port_name):
                        port = getattr(dut, port_name)
                        char_val = port.value
                        if is_value_defined(char_val):
                            char_int = int(char_val)
                            binary_str.append(chr(char_int))
                        else:
                            raise TestFailure(f"{port_name} undefined")
                    else:
                        raise TestFailure(f"Signal {port_name} not found")
            
            # Form the string
            result_str = ''.join(binary_str)
            
            # Trim spaces for comparison (the test expects exact string)
            # But we should compare exactly as per expected string
            if result_str != expected_str:
                raise TestFailure(f"Expected '{expected_str}', got '{result_str}'")
            
            passed += 1
            cocotb.log.info(f"  PASS")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed out of {passed+failed}")

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(CLK_NS, units='ns')
        if has_signal(dut, 'done'):
            done_val = dut.done.value
            if is_value_defined(done_val) and int(done_val) == 1:
                return True
        else:
            # If no done signal, wait a bit and assume done
            await Timer(100, units='ns')
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Note: The testbench above assumes the module has the exact interface as specified.
# It handles both array-of-signals and indexed array access patterns.
# The expected strings include exact character counts with spaces for padding to 16 chars.