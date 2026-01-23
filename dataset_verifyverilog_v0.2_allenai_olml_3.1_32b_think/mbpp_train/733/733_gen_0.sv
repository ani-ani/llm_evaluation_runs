module find_first_occurrence (
    input clk,
    input rst_n,
    input start,
    input [3:0] target,
    input [7:0] array_element_0,
    input [7:0] array_element_1,
    input [7:0] array_element_2,
    input [7:0] array_element_3,
    input [7:0] array_element_4,
    input [7:0] array_element_5,
    input [7:0] array_element_6,
    input [7:0] array_element_7,
    output reg [3:0] result,
    output reg done,
    output reg found
);

reg [2:0] state;
reg [2:0] left;
reg [2:0] right;
reg [3:0] result_reg;
reg [2:0] counter;

wire [7:0] selected_array;
wire comparison_lt, comparison_eq, comparison_gt;
wire [2:0] mid;
wire [7:0] target_extended;

assign selected_array = array_element_0 when (mid == 0) else array_element_1 when (mid == 1) else array_element_2 when (mid == 2) else array_element_3 when (mid == 3) else array_element_4 when (mid == 4) else array_element_5 when (mid == 5) else array_element_6 when (mid == 6) else array_element_7 when (mid == 7) else 8'b0;

assign mid = (left + right) >> 1;
assign target_extended = {4'b0, target};
assign comparison_lt = selected_array < target_extended;
assign comparison_eq = selected_array == target_extended;
assign comparison_gt = selected_array > target_extended;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= 0;
        left <= 0;
        right <= 7;
        result_reg <= 4'd15;
        counter <= 0;
        done <= 0;
    end else begin
        case (state)
            0: begin
                if (start) state <= 1;
            end
            1: begin
                left <= 0;
                right <= 7;
                result_reg <= 4'd15;
                counter <= 0;
                state <= 2;
            end
            2: state <= 3;
            3: begin
                if (comparison_eq) begin
                    result_reg <= mid;
                    right <= mid - 1;
                end else if (comparison_lt) begin
                    left <= mid + 1;
                end else begin
                    right <= mid - 1;
                end
                if (left <= right) begin
                    counter <= counter + 1;
                    if (counter > 3) begin
                        state <= 4;
                        done <= 1;
                    end else begin
                        state <= 2;
                    end
                end else begin
                    state <= 4;
                    done <= 1;
                end
            end
            4: begin
                state <= 4;
                done <= 1;
            end
            default: state <= state;
        endcase
    end
end

assign result = result_reg;
assign found = (result_reg != 4'd15);
assign done = done;

endmodule