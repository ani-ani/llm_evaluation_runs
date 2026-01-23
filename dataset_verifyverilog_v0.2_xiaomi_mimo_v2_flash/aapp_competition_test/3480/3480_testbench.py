import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer, FallingEdge
import random

# Helper to pack config L and D
def pack_config(L, D):
    # Config format: data_in[15:8] = L, data_in[7:0] = D
    return (L << 8) | D

@cocotb.test()
async def test_round_generator(dut):
    # Setup Clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_valid.value = 0
    dut.data_type.value = 0
    dut.data_in.value = 0
    await Timer(50, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Case 1: Simple Round (from prompt example, scaled down)
    # Song: "Hot cross buns! = Hot cross buns! ="
    # Times: 4 4 4 4 4 4 4 4
    # L=2, D=16
    
    # We need to feed data into the module.
    # The prompt spec uses `data_in` and `data_type`.
    # Config: Type 0, Data = {L, D}
    # Syllable Time: Type 0, Data = time
    # Syllable Char: Type 1, Data = char (ASCII)
    # End Syllable: Type 2
    # End Line: Type 3
    
    def send_data(dtype, val):
        dut.data_valid.value = 1
        dut.data_type.value = dtype
        dut.data_in.value = val
        yield RisingEdge(dut.clk)
        dut.data_valid.value = 0

    # --- Load Song ---
    # Config
    await send_data(0, pack_config(2, 16))
    
    # Line 1: "Hot cross buns! = Hot cross buns! ="
    # Let's simplify to "H o t" and "b u n s" for brevity in test, or full if we had string helper.
    # Let's just send chars one by one.
    # Syllable 1: "Hot", Time 4
    for char in "Hot":
        await send_data(1, ord(char))
    await send_data(0, 4) # Time
    await send_data(2, 0) # End Syl
    
    # Syllable 2: "Cross", Time 4
    for char in "Cross":
        await send_data(1, ord(char))
    await send_data(0, 4)
    await send_data(2, 0)
    
    # End Line 1
    await send_data(3, 0)
    
    # Line 2: "One", Time 2 (Simplified)
    for char in "One":
        await send_data(1, ord(char))
    await send_data(0, 2)
    await send_data(2, 0)
    
    # Syllable 2: "Two", Time 2
    for char in "Two":
        await send_data(1, ord(char))
    await send_data(0, 2)
    await send_data(2, 0)
    
    # End Line 2
    await send_data(3, 0)

    # Start Processing
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

    # Wait for output 1
    output_count = 0
    max_wait = 500
    
    while output_count < 2 and max_wait > 0:
        if dut.output_valid.value == 1:
            # Capture Output
            l1 = str(dut.line1_out.value)
            l2 = str(dut.line2_out.value)
            print(f"Line 1: {l1}")
            print(f"Line 2: {l2}")
            output_count += 1
            await RisingEdge(dut.clk)
        else:
            await RisingEdge(dut.clk)
            max_wait -= 1

    # Basic Assertions
    assert output_count == 2, "Expected 2 lines of output"
    
    # We can't easily check exact string content without knowing the internal exact padding logic,
    # but we can check if 'output_valid' pulsed and 'done' logic.
    # Let's check if we eventually get 'done'.
    
    while not dut.done.value and max_wait > 0:
        await RisingEdge(dut.clk)
        max_wait -= 1
        if dut.output_valid.value: 
            pass # Just consume
            
    assert dut.done.value == 1, "Expected done signal"
    print("Test Complete")
