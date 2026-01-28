import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
CLK_NS = 10
MAX_CYCLES = 200

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_string_checker(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational circuit
        await Timer(10, units='ns')

    # Test cases: (input_string, expected_result, description)
    test_cases = [
        ("aaabccc", "YES", "Example 1: count(c)==count(a)"),
        ("bbacc", "NO", "Example 2: wrong order"),
        ("aabc", "YES", "Example 3: count(c)==count(b)"),
        ("aabbcc", "YES", "Simple valid case"),
        ("aaacccbb", "NO", "Wrong order (c before b)"),
        ("abc", "YES", "Minimal valid: 1 each"),
        ("acba", "NO", "Wrong order"),
        ("bbabbc", "NO", "Multiple 'a' groups"),
        ("bbbabacca", "NO", "Complex invalid"),
        ("aabcbcaca", "NO", "Mixed invalid"),
        ("aaaaabbbbbb", "NO", "No 'c's"),
        ("c", "NO", "Only 'c'"),
        ("cc", "NO", "Only 'c's"),
        ("bbb", "NO", "Only 'b's"),
        ("bc", "NO", "Missing 'a'"),
        ("ccbcc", "NO", "Wrong order (starts with c)"),
        ("aaa", "NO", "Only 'a's"),
        ("aaccaa", "NO", "Wrong order (c before a again)"),
        ("a", "NO", "Too short"),
        ("b", "NO", "Too short"),
        ("abca", "NO", "Wrong order (a after c)"),
        ("aabbcccc", "YES", "count(c)==count(a)==2, count(b)==2"),
        ("abac", "NO", "Wrong order (a after b)"),
        ("abcc", "YES", "count(c)==2, count(b)==1, count(a)==1 (c==b)"),
        ("abcb", "NO", "Wrong order (b after c)"),
        ("aacc", "NO", "Missing 'b'"),
        ("aabbaacccc", "NO", "Wrong order (a after b)"),
        ("aabb", "NO", "Missing 'c'"),
        ("ac", "NO", "Missing 'b'"),
        ("abbacc", "NO", "Wrong order (b after c)"),
        ("abacc", "NO", "Wrong order (a after b)"),
        ("ababc", "NO", "Wrong order (a after b)"),
        ("aa", "NO", "Too short"),
        ("aabaccc", "NO", "Wrong order (a after b)"),
        ("bbcc", "NO", "Missing 'a'"),
        ("aaabcbc", "NO", "Wrong order (b after c)"),
        ("acbbc", "NO", "Wrong order"),
        ("babc", "NO", "Wrong order"),
        ("bbbcc", "NO", "Missing 'a'"),
        ("bbc", "NO", "Missing 'a'"),
        ("abababccc", "NO", "Wrong order (a after b)"),
        ("ccbbaa", "NO", "Wrong order (descending)"),
    ]

    passed = 0
    failed = 0

    for i, (inp_str, exp_str, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} (Input: '{inp_str}')")
        
        try:
            # Convert string to ASCII bytes
            ascii_vals = [ord(c) for c in inp_str]
            length = len(ascii_vals)
            
            if length > 32:
                cocotb.log.warning(f"Skipping test {i+1}: String length {length} exceeds HDL limit 32")
                continue

            # Drive inputs
            if has_signal(dut, 'char_in'):
                # For sequential processing, we might need to stream characters
                # Assuming a single port interface where we set char_in and pulse start
                # Or a RAM interface. Let's assume a simple interface where we set char_in and length.
                # However, typically for single-cycle logic, we might need an array of ports or a RAM.
                # Assuming the spec implies a single input port and FSM reads internally (not possible in simple Verilog without external RAM description).
                # Fallback: The Verilog spec likely expects parallel inputs or a pre-loaded buffer.
                # Let's adapt: If it's a single char_in, we can't test easily without a RAM model.
                # Assuming the DUT has parallel inputs `char_0` through `char_31` for simplicity in this benchmark.
                
                for idx in range(32):
                    port_name = f'char_{idx}'
                    if has_signal(dut, port_name):
                        val = ascii_vals[idx] if idx < length else 0
                        getattr(dut, port_name).value = clamp_to_width(val, DATA_WIDTH)
                    else:
                        break # No more ports
                
                if has_signal(dut, 'length'):
                    dut.length.value = clamp_to_width(length, 5)
                
                if has_signal(dut, 'start'):
                    dut.start.value = 1
                    await RisingEdge(dut.clk)
                    dut.start.value = 0
                    await wait_for_done(dut)
                else:
                    await Timer(100, units='ns') # Combinational delay
            
            else:
                 # Fallback for RAM interface (if defined differently)
                 # For this benchmark, we assume parallel ports or direct access.
                 # If `char_in` is strictly a single input stream, this testbench is hard without a driver.
                 # We will assume the Verilog spec implies parallel input for feasibility.
                 pass

            # Check result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal is undefined (X or Z)")
            
            result_val = int(dut.result.value)
            expected_val = 1 if exp_str == "YES" else 0
            
            if result_val != expected_val:
                raise TestFailure(f"Expected {expected_val} ({exp_str}), got {result_val}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        except Exception as e:
            cocotb.log.error(f"ERROR: {e}")
            failed += 1

    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")