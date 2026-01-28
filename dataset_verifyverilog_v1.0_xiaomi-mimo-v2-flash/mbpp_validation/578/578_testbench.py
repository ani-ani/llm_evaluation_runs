import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 200

# Helper Functions
def is_value_defined(v):
    try:
        int(v); return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name); return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout waiting for done after {max_cycles} cycles")

def pack_array(vals, bits=8):
    r = 0
    for i, v in enumerate(vals):
        r |= (v & ((1 << bits) - 1)) << (i * bits)
    return r

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_interleave(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational fallback
        dut.rst_n.value = 1

    # Test Cases
    # Format: (list1, list2, list3, expected_result_list)
    test_cases = [
        (
            [1,2,3,4,5,6,7],
            [10,20,30,40,50,60,70],
            [100,200,300,400,500,600,700],
            [1,10,100,2,20,200,3,30,300,4,40,400,5,50,500,6,60,600,7,70,700]
        ),
        (
            [10,20],
            [15,2],
            [5,10],
            [10,15,5,20,2,10]
        ),
        (
            [11,44],
            [10,15],
            [20,5],
            [11,10,20,44,15,5]
        ),
        (
            [0, 255],
            [0, 255],
            [0, 255],
            [0,0,0,255,255,255]
        )
    ]

    passed = 0
    failed = 0

    for i, (l1, l2, l3, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test Case {i+1}: Length {len(l1)}")
        try:
            if is_seq:
                # Check Ready
                if not is_value_defined(dut.ready.value):
                    raise TestFailure("Ready signal missing or undefined")
                if int(dut.ready.value) != 1:
                    raise TestFailure(f"Ready not high before start: {dut.ready.value}")

                # Write Arrays (Must be done element by element)
                # Pad inputs to full array size with 0 if smaller than ARRAY_SIZE
                for idx in range(ARRAY_SIZE):
                    val1 = l1[idx] if idx < len(l1) else 0
                    val2 = l2[idx] if idx < len(l2) else 0
                    val3 = l3[idx] if idx < len(l3) else 0
                    
                    if hasattr(dut, 'list1') and hasattr(dut.list1, '__getitem__'):
                        dut.list1[idx].value = clamp_to_width(val1, DATA_WIDTH)
                    elif hasattr(dut, f'list1_{idx}'):
                        getattr(dut, f'list1_{idx}').value = clamp_to_width(val1, DATA_WIDTH)
                    
                    if hasattr(dut, 'list2') and hasattr(dut.list2, '__getitem__'):
                        dut.list2[idx].value = clamp_to_width(val2, DATA_WIDTH)
                    elif hasattr(dut, f'list2_{idx}'):
                        getattr(dut, f'list2_{idx}').value = clamp_to_width(val2, DATA_WIDTH)

                    if hasattr(dut, 'list3') and hasattr(dut.list3, '__getitem__'):
                        dut.list3[idx].value = clamp_to_width(val3, DATA_WIDTH)
                    elif hasattr(dut, f'list3_{idx}'):
                        getattr(dut, f'list3_{idx}').value = clamp_to_width(val3, DATA_WIDTH)

                # Set Length
                dut.length.value = len(l1)

                # Pulse Start
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for Done and Collect Data
                result_data = []
                
                # We expect 3 * len(l1) cycles of data
                cycles_to_read = 3 * len(l1)
                
                # Wait for first data or done
                while len(result_data) < cycles_to_read:
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                        # Check if we finished exactly here
                        if len(result_data) == cycles_to_read - 1:
                            result_data.append(int(dut.result.value))
                            break
                    
                    if is_value_defined(dut.result.value):
                        val = int(dut.result.value)
                        result_data.append(val)
                    
                    await RisingEdge(dut.clk)
                    
                    # Safety break if done is high and we read it, or if we exceed expected cycles significantly
                    if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                         # If done is high, verify we have all data or grab last one
                         if len(result_data) < cycles_to_read:
                             result_data.append(int(dut.result.value))
                         break

                # Verify
                if result_data != expected:
                    raise TestFailure(f"Expected {expected}, got {result_data}")
                
                passed += 1
            else:
                # Combinational Logic Test
                # Write inputs immediately
                for idx in range(ARRAY_SIZE):
                    val1 = l1[idx] if idx < len(l1) else 0
                    val2 = l2[idx] if idx < len(l2) else 0
                    val3 = l3[idx] if idx < len(l3) else 0
                    
                    if hasattr(dut, 'list1') and hasattr(dut.list1, '__getitem__'):
                        dut.list1[idx].value = clamp_to_width(val1, DATA_WIDTH)
                    elif hasattr(dut, f'list1_{idx}'):
                        getattr(dut, f'list1_{idx}').value = clamp_to_width(val1, DATA_WIDTH)
                    
                    if hasattr(dut, 'list2') and hasattr(dut.list2, '__getitem__'):
                        dut.list2[idx].value = clamp_to_width(val2, DATA_WIDTH)
                    elif hasattr(dut, f'list2_{idx}'):
                        getattr(dut, f'list2_{idx}').value = clamp_to_width(val2, DATA_WIDTH)

                    if hasattr(dut, 'list3') and hasattr(dut.list3, '__getitem__'):
                        dut.list3[idx].value = clamp_to_width(val3, DATA_WIDTH)
                    elif hasattr(dut, f'list3_{idx}'):
                        getattr(dut, f'list3_{idx}').value = clamp_to_width(val3, DATA_WIDTH)

                dut.length.value = len(l1)
                await Timer(50, units='ns')
                
                # For combinational, we might need to handle multiple outputs or a single flat output vector
                # The prompt asked for a serialized output 'result' and a 'done' pulse.
                # Combinational interpretation: We check 'done' as a combinational valid flag and read 'result'.
                # However, usually combinational modules output a flat vector.
                # Let's assume the module is sequential as per prompt instructions ('State machine').
                # If strictly combinational was required by user but spec says sequential, we stick to spec.
                # We will assume the test expects the sequential behavior as described in the prompt.
                raise TestFailure("Module appears combinational, but prompt requires sequential handshake (start/ready/done). Ensure synthesis/sim settings match.")

        except TestFailure as e:
            cocotb.log.error(f"Test {i+1} FAILED: {e}")
            failed += 1
        except Exception as e:
            cocotb.log.error(f"Test {i+1} ERROR: {e}")
            failed += 1

    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed out of {len(test_cases)}")
