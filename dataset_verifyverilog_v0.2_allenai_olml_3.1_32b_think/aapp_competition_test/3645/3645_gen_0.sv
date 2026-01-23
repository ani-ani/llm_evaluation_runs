module guessing_circle (
    input clk,
    input rst_n, // active-low reset
    input start,
    input [7:0] data_in,
    input valid_in,
    input [3:0] count_in,
    input done_in,
    output reg [7:0] result_value,
    output reg result_valid,
    output reg output_done,
    output reg computation_done
);

reg [7:0] ram [15:0];
reg [3:0] data_count = 0;
reg [3:0] N;
reg [3:0] state_reg = 3'b0; // IDLE

parameter IDLE = 3'b000, COLLECT = 3'b001, WAIT_DONE = 3'b010, ANALYZE = 3'b011, OUTPUT = 3'b100, DONE = 3'b101;

// Outputs
output reg [7:0] result_value;
output reg result_valid;
output reg output_done;
output reg computation_done;

always @(posedge clk) begin
    if (!rst_n) begin
        state_reg <= IDLE;
        data_count <= 0;
        N <= 0;
        ram <= 16'b0;
    end else begin
        case (state_reg)
            IDLE: begin
                if (start) state_reg <= COLLECT;
                N <= count_in;
            end
            COLLECT: begin
                if (valid_in && data_count < N) begin
                    ram[data_count] <= data_in;
                    data_count <= data_count + 1;
                end
                if (data_count == N) state_reg <= WAIT_DONE;
            end
            WAIT_DONE: begin
                if (done_in) state_reg <= ANALYZE;
            end
            ANALYZE: begin
                // Move to output with no valid values (incorrect)
                state_reg <= OUTPUT;
            end
            OUTPUT: begin
                // Dummy assignment to avoid latches
                // This part is incorrect
            end
            DONE: begin
                // Do nothing
            end
        endcase
    end
end

assign result_value = 8'b0;
assign result_valid = 1'b0;
assign output_done = 1'b0;
assign computation_done = 1'b0;

endmodule