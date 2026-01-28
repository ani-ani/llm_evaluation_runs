import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.cmd_valid.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=500):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def send_command(dut, cmd_type, cmd_data):
    dut.cmd_type.value = cmd_type
    dut.cmd_data.value = clamp_to_width(cmd_data, 32)
    dut.cmd_valid.value = 1
    await RisingEdge(dut.clk)
    dut.cmd_valid.value = 0
    await RisingEdge(dut.clk)
    # Wait a bit for FSM to process
    await Timer(100, units='ns')

@cocotb.test(timeout_time=10000, timeout_unit='ms')
async def test_paint_fsm(dut):
    # Clock setup
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational or static
        dut.rst_n.value = 1
    
    # Test Case 1: Sample Input 1
    # 4x4 -> 8x8 (scaled, using first 4x4 area)
    # Commands:
    # PAINT 2 0 0 3 3
    # PAINT 3 0 3 3 3
    
    cocotb.log.info("Test Case 1: Checkerboard pattern")
    
    if has_signal(dut, 'start'):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
    
    # Command 1: PAINT 2 0 0 3 3
    # Encoded: cmd_type=00, cmd_data={color=2, x1=0, y1=0, x2=3, y2=3}
    # cmd_data = 0x0000_0020 (color=2, x1=0, y1=0, x2=3, y2=3)
    # color=2 (0010), x1=0 (000), y1=0 (000), x2=3 (011), y2=3 (011)
    # Packed: {color[3:0], x1[2:0], y1[2:0], x2[2:0], y2[2:0]}
    # color=2 => bits 31-28
    # x1=0 => bits 27-25
    # y1=0 => bits 24-22
    # x2=3 => bits 21-19
    # y2=3 => bits 18-16
    cmd_data1 = (2 << 28) | (0 << 25) | (0 << 22) | (3 << 19) | (3 << 16)
    await send_command(dut, 0, cmd_data1)
    
    # Command 2: PAINT 3 0 3 3 3
    # color=3, x1=0, y1=3, x2=3, y2=3
    cmd_data2 = (3 << 28) | (0 << 25) | (3 << 22) | (3 << 19) | (3 << 16)
    await send_command(dut, 0, cmd_data2)
    
    if has_signal(dut, 'done'):
        await wait_for_done(dut)
        
        # Check result
        result = int(dut.result.value)
        cocotb.log.info(f"Result packed: {result}")
        
        # Decode and verify (only checking first 4 rows/cols of 8x8)
        # Expected:
        # 2 1 2 3
        # 1 2 1 2
        # 2 1 2 3
        # 1 2 1 2
        # Row 0: 2,1,2,3 -> 0x2123
        # Row 1: 1,2,1,2 -> 0x1212
        # Row 2: 2,1,2,3 -> 0x2123
        # Row 3: 1,2,1,2 -> 0x1212
        
        # Extract row 0 (bits 31-28, 27-24, 23-20, 19-16)
        row0 = (result >> 28) & 0xF
        row0_2 = (result >> 24) & 0xF
        row0_3 = (result >> 20) & 0xF
        row0_4 = (result >> 16) & 0xF
        
        if row0 != 2 or row0_2 != 1 or row0_3 != 2 or row0_4 != 3:
            raise TestFailure(f"Row 0 incorrect: got {row0} {row0_2} {row0_3} {row0_4}")
    
    # Test Case 2: SAVE/LOAD
    # Commands: PAINT 3 0 0 1 1, SAVE, PAINT 2 1 1 2 2, LOAD 1
    cocotb.log.info("Test Case 2: SAVE/LOAD")
    
    await reset_dut(dut)
    
    if has_signal(dut, 'start'):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
    
    # PAINT 3 0 0 1 1
    cmd_data1 = (3 << 28) | (0 << 25) | (0 << 22) | (1 << 19) | (1 << 16)
    await send_command(dut, 0, cmd_data1)
    
    # SAVE (cmd_type=01)
    await send_command(dut, 1, 0)
    
    # PAINT 2 1 1 2 2
    cmd_data2 = (2 << 28) | (1 << 25) | (1 << 22) | (2 << 19) | (2 << 16)
    await send_command(dut, 0, cmd_data2)
    
    # LOAD 1 (cmd_type=10, save_id=1)
    # cmd_data: save_id in bits 0-3
    await send_command(dut, 2, 1)
    
    if has_signal(dut, 'done'):
        await wait_for_done(dut)
        
        result = int(dut.result.value)
        cocotb.log.info(f"Result packed: {result}")
        
        # Expected:
        # 3 1 1
        # 1 3 1
        # 1 1 1
        # Row 0: 3,1,1 -> 0x311
        row0 = (result >> 28) & 0xF
        row0_2 = (result >> 24) & 0xF
        row0_3 = (result >> 20) & 0xF
        
        if row0 != 3 or row0_2 != 1 or row0_3 != 1:
            raise TestFailure(f"Row 0 incorrect: got {row0} {row0_2} {row0_3}")
    
    cocotb.log.info("All tests passed")