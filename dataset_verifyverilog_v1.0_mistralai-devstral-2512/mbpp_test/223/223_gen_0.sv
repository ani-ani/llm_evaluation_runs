module majority_checker(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:15],
    input [3:0] len,
    input [7:0] target,
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] SEARCH  = 3'd1;
    localparam [2:0] CHECK   = 3'd2;
    localparam [2:0] DONE    = 3'd3;

    reg [2:0] state;
    reg [3:0] low;
    reg [3:0] high;
    reg [3:0] mid;
    reg [3:0] first_occurrence;
    reg found;
    reg [3:0] iteration_count;
    localparam [3:0] MAX_ITERATIONS = 4'd16;

    // Combinational logic for binary search
    wire [3:0] next_mid = (low + high) >> 1;
    wire [7:0] arr_mid = arr[next_mid];
    wire [7:0] arr_mid_minus_1 = (next_mid == 4'd0) ? 8'd0 : arr[next_mid - 1];
    wire is_first_occurrence = (arr_mid == target) && (arr_mid_minus_1 < target);
    wire [3:0] n_div_2 = len >> 1;
    wire [3:0] mid_plus_n_div_2 = next_mid + n_div_2;
    wire [7:0] arr_mid_plus_n_div_2 = (mid_plus_n_div_2 < len) ? arr[mid_plus_n_div_2] : 8'd0;
    wire is_majority = (mid_plus_n_div_2 < len) && (arr_mid_plus_n_div_2 == target);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            low <= 4'd0;
            high <= 4'd0;
            mid <= 4'd0;
            first_occurrence <= 4'd0;
            found <= 1'b0;
            iteration_count <= 4'd0;
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    if (start) begin
                        state <= SEARCH;
                        low <= 4'd0;
                        high <= len - 4'd1;
                        iteration_count <= 4'd0;
                        found <= 1'b0;
                    end
                end

                SEARCH: begin
                    iteration_count <= iteration_count + 4'd1;
                    mid <= next_mid;

                    if (is_first_occurrence) begin
                        first_occurrence <= mid;
                        found <= 1'b1;
                        state <= CHECK;
                    end else if (arr_mid < target) begin
                        low <= mid + 4'd1;
                    end else begin
                        high <= mid - 4'd1;
                    end

                    if (iteration_count >= MAX_ITERATIONS || low > high) begin
                        state <= CHECK;
                    end
                end

                CHECK: begin
                    if (found && (first_occurrence + n_div_2 < len) && (arr[first_occurrence + n_div_2] == target)) begin
                        result <= 1'b1;
                    end else begin
                        result <= 1'b0;
                    end
                    state <= DONE;
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule