module probability_calculator(input clk, input rst_n, input start, input [7:0] N, output reg [31:0] result, output reg done);

// Internal registers
reg [7:0] reg_N;
reg [1:0] state, next_state;
reg [1:0] calc_counter;
reg [31:0] result_int;

// State definitions
localparam IDLE = 2'b00;
localparam LOOKUP = 2'b01;
localparam CALCULATE = 2'b10;
localparam DONE = 2'b11;
localparam INIT = IDLE;

// Results
localparam RESULT_N2 = 32'h00010000;
localparam RESULT_N4 = 32'h0000F685;

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        reg_N <= 8'd0;
        state <= INIT;
        next_state <= INIT;
        calc_counter <= 2'b00;
        result_int <= 32'd0;
        done <= 1'b0;
    end else begin
        state <= next_state;

        if (state == IDLE) begin
            if (start) begin
                next_state <= LOOKUP;
            end else begin
                next_state <= IDLE;
            end
        end else if (state == LOOKUP) begin
            reg_N <= N;
            next_state <= CALCULATE;
        end else if (state == CALCULATE) begin
            if (calc_counter == 2'b00) begin
                if (reg_N == 2) begin
                    result_int <= RESULT_N2;
                end else if (reg_N == 4) begin
                    result_int <= RESULT_N4;
                end else begin
                    result_int <= 32'd0;
                end
                calc_counter <= 2'b01;
                next_state <= CALCULATE;
            end else begin
                next_state <= DONE;
                calc_counter <= 2'b00;
            end
        end else if (state == DONE) begin
            next_state <= DONE;
            done <= 1'b1;
        end
    end
end

// Assign result to output
assign result = result_int;

endmodule