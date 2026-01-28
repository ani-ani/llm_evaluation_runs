import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
DATA_WIDTH = 8
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 1000

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

def gcd(a, b):
    while b: a, b = b, a % b
    return a

def get_expected_distinct_gcds(arr, n):
    gcd_set = set()
    for i in range(n):
        current_gcd = 0
        for j in range(i, n):
            current_gcd = gcd(current_gcd, arr[j])
            gcd_set.add(current_gcd)
    return len(gcd_set)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_collatz_distinct_gcd(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        for _ in range(2): await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        await Timer(100, units='ns')

    test_cases = [
        ([9, 6, 2, 4], 4),  # Expected distinct gcds: 6
        ([9, 6, 3, 4], 4),  # Expected distinct gcds: 5
        ([1, 1, 1, 1], 4),  # Expected distinct gcds: 1
        ([2, 4, 6, 8], 4),  # Expected distinct gcds: 4 (2,4,6,8 -> 2,4,6,8? No: GCDs are 2,2,2,2,6,6,8 -> 2,6,8 = 3)
        # Let's trace [2,4,6,8]:
        # 2: [2]->2, [2,4]->2, [2,4,6]->2, [2,4,6,8]->2
        # 4: [4]->4, [4,6]->2, [4,6,8]->2
        # 6: [6]->6, [6,8]->2
        # 8: [8]->8
        # Distinct: 2, 4, 6, 8. Count = 4.
        # Wait, [4,6,8] gcd is 2. [4,6] is 2.
        # Distinct values: 2, 4, 6, 8. Total 4.
        ([2, 4, 6, 8], 4),
        ([3, 6, 9, 12], 4), # GCDs: 3, 3, 3, 3, 3, 3, 12? No, [9,12]=3. Distinct: 3, 6, 9, 12. Count 4.
        ([1, 2, 3, 4], 4),  # Distinct: 1,2,3,4. Count 4.
    ]

    passed = 0
    failed = 0

    for i, (values, n) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: Sequence {values} (len {n})")
        try:
            expected = get_expected_distinct_gcds(values, n)
            
            # Set input array
            # Individual assignment
            for idx in range(ARRAY_SIZE):
                val = values[idx] if idx < n else 0
                # Check if specific array ports exist (arr_0, arr_1...) or array index (arr[idx])
                if hasattr(dut, f'arr_{idx}'):
                    getattr(dut, f'arr_{idx}').value = clamp_to_width(val, DATA_WIDTH)
                elif hasattr(dut, 'arr') and len(dut.arr) > idx:
                    dut.arr[idx].value = clamp_to_width(val, DATA_WIDTH)
                else:
                    raise TestFailure(f"Cannot access array index {idx}")
            
            # Set length
            if hasattr(dut, 'len'):
                dut.len.value = n
            else:
                 cocotb.log.warning("Signal 'len' not found, assuming fixed size or testbench handles it internally")

            # Start
            if is_seq:
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                done_found = False
                for _ in range(MAX_CYCLES):
                    await RisingEdge(dut.clk)
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        done_found = True
                        break
                
                if not done_found:
                    raise TestFailure(f"Timeout waiting for done signal")
                
                # Read result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result signal undefined")
                
                result = int(dut.result.value)
            else:
                # Combinational
                await Timer(100, units='ns')
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result signal undefined")
                result = int(dut.result.value)

            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASSED: Result {result}")

        except TestFailure as e:
            cocotb.log.error(f"FAIL: Test {i+1}: {e}")
            failed += 1

    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed out of {passed + failed}")