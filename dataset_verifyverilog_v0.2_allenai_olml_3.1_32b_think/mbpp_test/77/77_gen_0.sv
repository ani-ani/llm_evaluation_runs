module divisible_by_11 (
    input clk,
    input rst_n,
    input start,
    input [31:0] number,
    output reg result,
    output reg done
);

reg [1:0] state_reg;
reg [31:0] num_reg;
reg [3:0] remainder_reg;
reg [4:0] bit_counter;
reg result_reg;
reg done_reg;

localparam IDLE = 2'd0;
localparam PROCESSING = 2'd1;
localparam DONE = 2'd2;

assign result = result_reg;
assign done = done_reg;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state_reg <= IDLE;
        num_reg <= 32'd0;
        remainder_reg <= 4'd0;
        bit_counter <= 5'd0;
        result_reg <= 1'b0;
        done_reg <= 1'b0;
    end else begin
        case (state_reg)
            IDLE: begin
                done_reg <= 1'b0;
                if (start == 1) begin
                    state_reg <= PROCESSING;
                    num_reg <= number;
                    remainder_reg <= 4'd0;
                    bit_counter <= 31;
                end
            end
            PROCESSING: begin
                done_reg <= 1'b0;
                if (bit_counter >= 5'd0) begin
                    remainder_reg <= ( ( (remainder_reg * 2 + ((num_reg >> bit_counter) & 1)) >= 11 ) ? (remainder_reg * 2 + ((num_reg >> bit_counter) & 1) - 11) : (remainder_reg * 2 + ((num_reg >> bit_counter) & 1)) );
                    bit_counter <= bit_counter - 1;
                    state_reg <= PROCESSING;
                end else begin
                    state_reg <= DONE;
                    result_reg <= (remainder_reg == 4'd0);
                end
            end
            DONE: begin
                done_reg <= 1'b1;
                state_reg <= DONE;
            end
        endcase
    end
endmodule