import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_matrix_recover(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    test_cases = [
        ('0110', '1001', '1111\\
0111\\
1110\\
1111', True),
        ('0', '1', '', False),  # Invalid after padding
        ('11', '0110', '1011\\
1101', True)  # 2x4 matrix (threshold)
    ]
    passed = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    for r_str, c_str, expected, valid_exp in test_cases:
        # Pad inputs to 4 bits
        r_val = int(r_str.ljust(4, '0')[::-1], 2)
        c_val = int(c_str.ljust(4, '0')[::-1], 2)
        dut.R.value = r_val
        dut.C.value = c_val
        await RisingEdge(dut.clk)
        # Wait 10 cycles for computation
        for _ in range(10):
            await RisingEdge(dut.clk)
        # Check results
        if dut.valid.value == valid_exp:
            if valid_exp:
                # Compare binary matrix representation
                flat_matrix = ''.join(format(dut.matrix.value >> (4*i) & 0xf, '04b') for i in range(3,-1,-1))
                expected_flat = expected.replace('\\
', '').strip()
                if flat_matrix.startswith(expected_flat.ljust(16, '0')):
                    passed += 1
                else:
                    dut._log.error(f"Matrix mismatch: got {flat_matrix}, expected {expected_flat}")
            else:
                passed += 1
        else:
            dut._log.error(f"Validity mismatch: got {dut.valid.value}, expected {valid_exp}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
