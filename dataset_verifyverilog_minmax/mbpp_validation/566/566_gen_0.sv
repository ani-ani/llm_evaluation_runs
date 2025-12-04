module digit_sum (
    input clk,
    input rst_n,
    input start,
    input [15:0] num,
    output reg [5:0] sum,
    output reg done
);

    // ROM for division by 10 lookup table
    wire [19:0] div10_rom [0:65535];
    genvar i;
    generate
        for (i=0; i<65536; i++) begin : rom_gen
            assign div10_rom[i] = { (i/10), (i%10) };
        end
    endgenerate

    // Intermediate combinational signals
    reg [15:0] curr_quot;
    reg [3:0] curr_rem;

    // Combinational block to read the ROM
    always @(*) begin
        if (start) begin
            {curr_quot, curr_rem} = div10_rom[num];
        end else begin
            {curr_quot, curr_rem} = div10_rom[working_reg];
        end
    end

    // Working register for the number being processed
    reg [15:0] working_reg;

    // Sequential block for state and outputs
    always @(posedge clk, negedge rst_n) begin
        if (!rst_n) begin
            working_reg <= 0;
            sum <= 0;
            done <= 0;
        end else begin
            if (start) begin
                working_reg <= curr_quot;
                sum <= {2'b0, curr_rem};
                done <= (curr_quot == 0);
            end else if (!done) begin
                working_reg <= curr_quot;
                sum <= sum + {2'b0, curr_rem};
                done <= (curr_quot == 0);
            end
        end
    end

endmodule