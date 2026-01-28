import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, int(v)))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_lcd_activator(dut):
    # Setup
    CLK_NS = 10
    MAX_CYCLES = 10000
    
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        if has_signal(dut, 'valid_i'): dut.valid_i.value = 0
        await Timer(20, units='ns')
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        await Timer(20, units='ns')

    # Test data: (direction, time, length, wire) -> direction: 0=h, 1=v
    # Sample Input 1:
    # h 1 4 1
    # v 2 4 2
    # h 10 2 2
    # v 11 2 3
    # Output: 2
    # Intersections:
    # (h1, v2) -> pixel(2,1): h1 active [1,5), v2 active [2,6) -> overlap [2,5) -> Yes
    # (h2, v2) -> pixel(2,2): h2 active [10,12), v2 active [2,6) -> No
    # (h1, v3) -> pixel(3,1): h1 active [1,5), v3 active [11,13) -> No
    # (h2, v3) -> pixel(3,2): h2 active [10,12), v3 active [11,13) -> overlap [11,12) -> Yes
    # Total: 2
    
    test_inputs = [
        # Input 1
        [
            (0, 1, 4, 1),  # h 1 4 1
            (1, 2, 4, 2),  # v 2 4 2
            (0, 10, 2, 2), # h 10 2 2
            (1, 11, 2, 3)  # v 11 2 3
        ],
        # Input 2
        # h 1 10 1
        # h 5 10 2
        # v 1 10 1
        # v 5 10 3
        # Output: 4
        # (h1,v1): [1,11) vs [1,11) -> Yes
        # (h2,v1): [5,15) vs [1,11) -> Yes
        # (h1,v3): [1,11) vs [5,15) -> Yes
        # (h2,v3): [5,15) vs [5,15) -> Yes
        [
            (0, 1, 10, 1),
            (0, 5, 10, 2),
            (1, 1, 10, 1),
            (1, 5, 10, 3)
        ],
        # Input 3
        # v 1 3 1
        # v 1 15 2
        # h 4 5 1
        # h 5 5 2
        # h 6 5 3
        # h 7 5 4
        # h 8 5 5
        # Output: 5
        # v1: [1,4)
        # v2: [1,16)
        # h1: [4,9)
        # h2: [5,10)
        # h3: [6,11)
        # h4: [7,12)
        # h5: [8,13)
        # Vertices:
        # (v1, h1) pixel(1,1): [1,4) vs [4,9) -> No (edge touch not active)
        # (v1, h2) pixel(1,2): [1,4) vs [5,10) -> No
        # ...
        # (v2, h1) pixel(2,1): [1,16) vs [4,9) -> Yes
        # (v2, h2) pixel(2,2): [1,16) vs [5,10) -> Yes
        # (v2, h3) pixel(2,3): [1,16) vs [6,11) -> Yes
        # (v2, h4) pixel(2,4): [1,16) vs [7,12) -> Yes
        # (v2, h5) pixel(2,5): [1,16) vs [8,13) -> Yes
        # Total: 5
        [
            (1, 1, 3, 1),
            (1, 1, 15, 2),
            (0, 4, 5, 1),
            (0, 5, 5, 2),
            (0, 6, 5, 3),
            (0, 7, 5, 4),
            (0, 8, 5, 5)
        ]
    ]

    expected_outputs = [2, 4, 5]

    for idx, (pulses, expected) in enumerate(zip(test_inputs, expected_outputs)):
        cocotb.log.info(f"Running Test Case {idx + 1}")
        
        # 1. Start processing
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
        else:
            # If no start, just proceed
            await RisingEdge(dut.clk)
        
        # 2. Feed pulses serially
        if has_signal(dut, 'valid_i'):
            for direction, t, m, a in pulses:
                dut.valid_i.value = 1
                dut.pulse_direction.value = direction
                dut.pulse_time.value = clamp_to_width(t, 16)
                dut.pulse_length.value = clamp_to_width(m, 16)
                dut.pulse_wire.value = clamp_to_width(a - 1, 5) # 0-based index
                await RisingEdge(dut.clk)
            dut.valid_i.value = 0
        
        # 3. Wait for done
        if has_signal(dut, 'done'):
            found_done = False
            for _ in range(MAX_CYCLES):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    found_done = True
                    break
            if not found_done:
                raise TestFailure(f"Test {idx+1} timed out waiting for done")
        else:
            # Combinational logic assumption or fixed delay
            await Timer(500, units='ns')
            
        # 4. Check result
        if has_signal(dut, 'result'):
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Test {idx+1} result is undefined")
            
            result_val = int(dut.result.value)
            if result_val != expected:
                raise TestFailure(f"Test {idx+1} failed. Expected {expected}, got {result_val}")
            else:
                cocotb.log.info(f"Test {idx+1} Passed")
        else:
             cocotb.log.info("No result signal found, skipping check")

        # Reset before next test
        if has_signal(dut, 'rst_n'):
            dut.rst_n.value = 0
            await Timer(20, units='ns')
            dut.rst_n.value = 1
            await RisingEdge(dut.clk)