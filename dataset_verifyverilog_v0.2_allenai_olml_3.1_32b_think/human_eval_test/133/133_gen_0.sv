module sum_squares (
    input clk,
    input rst_n,
    input start,
    input [4:0] num_elements,
    input [31:0] input_list [0:7],
    output reg [31:0] result,
    output reg done
);
localparam IDLE = 3'b000, LOAD=3'b001, CEIL=3'b010, SQUARE=3'b011, ACCUM=3'b100, DONE=3'b101;
reg [2:0] state, element_idx;
reg [31:0] accumulator, current_value, square_val;
reg [4:0] total_elements;
reg done;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        element_idx <= 3'b0;
        accumulator <= 32'd0;
        current_value <= 32'd0;
        square_val <= 32'd0;
        total_elements <= 5'd0;
        done <= 1'b0;
    end
end

always @(posedge clk) begin
    if (state == IDLE) begin
        if (start) begin
            total_elements <= num_elements;
            element_idx <= 3'b0;
            state <= LOAD;
        end else begin
            state <= IDLE;
        end
    end else if (state == LOAD) begin
        current_value <= input_list[element_idx];
        state <= CEIL;
    end else if (state == CEIL) begin
        signed [31:0] temp = current_value;
        signed [15:0] int_part = temp >> 16;
        reg [15:0] frac_part = temp & 16'd0xFFFF;
        if (temp >= 0 && frac_part > 0) begin
            current_value = int_part + 1;
        end else begin
            current_value = int_part;
        end
        state <= SQUARE;
    end else if (state == SQUARE) begin
        square_val <= current_value * current_value;
        state <= ACCUM;
    end else if (state == ACCUM) begin
        accumulator <= accumulator + (square_val << 16);
        element_idx <= element_idx + 1;
        if (element_idx < total_elements) begin
            state <= LOAD;
        end else begin
            state <= DONE;
            done <= 1'b1;
        end
    end else if (state == DONE) begin
        state <= DONE;
    end
end

assign result = accumulator;
endmodule