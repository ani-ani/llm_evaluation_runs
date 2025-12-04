module testbench;
    reg clk;
    reg [7:0] data_in;
    wire [7:0] data_out;

    // Instantiate the DUT
    dut u_dut (
        .clk(clk),
        .data_in(data_in),
        .data_out(data_out)
    );

    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Stimulus
    initial begin
        data_in = 8'h00;
        #10 data_in = 8'hFF;
        #10 data_in = 8'hAA;
        #10 data_in = 8'h55;
        #10 $finish;
    end

    // Monitor
    initial begin
        $monitor("Time = %0t, data_in = %h, data_out = %h", $time, data_in, data_out);
    end
endmodule