import cocotb
from cocotb.triggers import Timer
@cocotb.test()
async def test_clock_corrector(dut):
    test_cases = [
        # Format 24-bit, time, expected
        (1, 1,7,3,0, 1,7,3,0), # 24: 17:30 unchanged
        (0, 1,7,3,0, 0,7,3,0), # 12: 17:30 → 07:30
        (1, 9,9,9,9, 0,9,0,9), # 24: 99:99 → 09:09
        (0, 0,0,0,5, 0,1,0,5), # 12: 00:05 → 01:05
        (1, 7,3,1,6, 0,3,1,6), # 24: 73:16 → 03:16
        (0, 4,7,8,3, 0,7,0,3), # 12: 47:83 → 07:03
        (1, 3,4,0,0, 0,4,0,0), # 24: 34:00 → 04:00
        (0, 0,0,6,0, 0,1,0,0)  # 12: 00:60 → 01:00
    ]
    passed = 0
    for fmt, h_tens_in, h_units_in, m_tens_in, m_units_in,
            h_tens_exp, h_units_exp, m_tens_exp, m_units_exp in test_cases:
        dut.is_24h_format.value = fmt
        dut.hour_tens.value = h_tens_in
        dut.hour_units.value = h_units_in
        dut.min_tens.value = m_tens_in
        dut.min_units.value = m_units_in
        await Timer(1, units='ns')
        corr = (dut.corr_hour_tens.value, dut.corr_hour_units.value,
                dut.corr_min_tens.value, dut.corr_min_units.value)
        expected = (h_tens_exp, h_units_exp, m_tens_exp, m_units_exp)
        if corr == expected:
            passed += 1
        else:
            dut._log.error("Failed: Input %01d%01d:%01d%01d (fmt=%d) → Output %d%d:%d%d, Expected %d%d:%d%d" % 
                (h_tens_in, h_units_in, m_tens_in, m_units_in, fmt, *corr, *expected))
    dut._log.info("%d/%d tests passed" % (passed, len(test_cases)))