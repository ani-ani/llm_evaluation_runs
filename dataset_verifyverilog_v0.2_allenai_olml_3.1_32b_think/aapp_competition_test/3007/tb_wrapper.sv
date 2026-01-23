// tb_wrapper.sv - Wrapper for waveform dumping
`timescale 1ns/1ps

module tb_wrapper;
    // This is just for waveform dumping
    initial begin
        $dumpfile("waves.vcd");
        $dumpvars(0, max_bling_calculator);
        #100000;  // Timeout after 100us
        $finish;
    end
endmodule