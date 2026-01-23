module first_digit (
    input clk,
    input rst_n,
    input start,
    input [31:0] num,
    output reg [3:0] first_digit,
    output reg done
);

// Registers
reg [31:0] temp_num;
reg [2:0] state;
reg [31:0] count;
reg [3:0] first_digit_reg;
reg done_reg;

localparam IDLE = 3'd0;
localparam CALCULATING = 3'd1;
localparam SUBTRACT = 3'd2;
localparam DONE = 3'd3;

always_ff @(posedge clk) begin
    if (!rst_n) begin
        temp_num <= 32'd0;
        state <= IDLE;
        count <= 32'd0;
        first_digit_reg <= 4'd0;
        done_reg <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    temp_num <= num;
                    state <= CALCULATING;
                end
            end
            CALCULATING: begin
                if (temp_num < 10) begin
                    first_digit_reg <= temp_num[3:0];
                    done_reg <= 1'b1;
                    state <= DONE;
                end else begin
                    count <= 32'd0;
                    state <= SUBTRACT;
                end
            end
            SUBTRACT: begin
                if (temp_num >= 10) begin
                    temp_num <= temp_num - 10;
                    count <= count + 1;
                end else begin
                    temp_num <= count;
                    state <= CALCULATING;
                end
            end
            DONE: begin
                // Remain in DONE state
            end
        endcase
    end
end

assign first_digit = first_digit_reg;
assign done = done_reg;

endmodule