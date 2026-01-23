module max_product_subarray (
    input clk,
    input rst_n,
    input start,
    input [5:0] array_length,
    input [15:0] array_data [0:7],
    output reg [31:0] result,
    output reg done
);

localparam ARRAY_MAX = 8;
localparam CYCLES_PER_ELEMENT = 5;
localparam TOTAL_CYCLES = ARRAY_MAX * CYCLES_PER_ELEMENT;

reg [31:0] max_ending_here, min_ending_here, max_so_far;
reg [2:0] current_index, cycle_counter;
reg [31:0] element_int, temp_max, temp_min;
reg [31:0] element;
reg done_reg;

always @(posedge clk) begin
    if (!rst_n) begin
        max_ending_here <= 32'd0;
        min_ending_here <= 32'd0;
        max_so_far <= 32'd0;
        current_index <= 3'd0;
        cycle_counter <= 3'd0;
        done_reg <= 1'b0;
    end else begin
        if (start) begin
            if (cycle_counter == 3'd0 && current_index < ARRAY_MAX) begin
                element <= array_data[current_index];
                element_int <= { {16{element[15]}}, element };
                if (current_index == 3'd0) begin
                    max_ending_here <= element_int;
                    min_ending_here <= element_int;
                    max_so_far <= element_int;
                end else begin
                    temp_max <= element_int;
                    temp_min <= element_int;
                    if (max_ending_here * element_int > temp_max) temp_max <= max_ending_here * element_int;
                    if (min_ending_here * element_int > temp_max) temp_max <= min_ending_here * element_int;
                    if (max_ending_here * element_int < temp_min) temp_min <= max_ending_here * element_int;
                    if (min_ending_here * element_int < temp_min) temp_min <= min_ending_here * element_int;
                    max_ending_here <= temp_max;
                    min_ending_here <= temp_min;
                    max_so_far <= (max_so_far > temp_max) ? max_so_far : temp_max;
                end
                if (current_index < array_length - 1) begin
                    current_index <= current_index + 3'd1;
                    cycle_counter <= 3'd0;
                end else begin
                    if (current_index < array_length) begin
                        current_index <= current_index + 3'd1;
                        cycle_counter <= 3'd0;
                    end
                end
            end
        end
        if (cycle_counter < CYCLES_PER_ELEMENT - 1) begin
            cycle_counter <= cycle_counter + 3'd1;
        end else begin
            cycle_counter <= 3'd0;
            if (current_index >= array_length && current_index >= ARRAY_MAX - 1) begin
                done_reg <= 1'b1;
            end
        end
    end
end

assign result = (max_so_far >= 32'd0) ? (max_so_far << 16) : 32'd0;
assign done = done_reg;

endmodule