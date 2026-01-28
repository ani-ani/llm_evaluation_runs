module matrix_sorter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [3:0] matrix_00,
    input wire signed [3:0] matrix_01,
    input wire signed [3:0] matrix_02,
    input wire signed [3:0] matrix_10,
    input wire signed [3:0] matrix_11,
    input wire signed [3:0] matrix_12,
    input wire signed [3:0] matrix_20,
    input wire signed [3:0] matrix_21,
    input wire signed [3:0] matrix_22,
    output reg [35:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] CALC_SUMS = 3'd1;
    localparam [2:0] SORT      = 3'd2;
    localparam [2:0] OUTPUT    = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Row data registers (3 rows x 3 elements, 4-bit signed)
    reg signed [3:0] row0 [0:2];
    reg signed [3:0] row1 [0:2];
    reg signed [3:0] row2 [0:2];

    // Row sum registers (6-bit signed)
    reg signed [5:0] sum0, sum1, sum2;

    // Temporary registers for sorting
    reg signed [3:0] temp_row [0:2];
    reg signed [5:0] temp_sum;

    // Cycle counter for sorting
    reg [1:0] sort_cycle;
    reg [1:0] sort_iteration;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            result <= 36'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            sort_cycle <= 2'd0;
            sort_iteration <= 2'd0;

            // Initialize row registers
            row0[0] <= 4'd0; row0[1] <= 4'd0; row0[2] <= 4'd0;
            row1[0] <= 4'd0; row1[1] <= 4'd0; row1[2] <= 4'd0;
            row2[0] <= 4'd0; row2[1] <= 4'd0; row2[2] <= 4'd0;

            // Initialize sum registers
            sum0 <= 6'd0;
            sum1 <= 6'd0;
            sum2 <= 6'd0;
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= CALC_SUMS;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                CALC_SUMS: begin
                    // Load input matrix into row registers
                    row0[0] <= matrix_00; row0[1] <= matrix_01; row0[2] <= matrix_02;
                    row1[0] <= matrix_10; row1[1] <= matrix_11; row1[2] <= matrix_12;
                    row2[0] <= matrix_20; row2[1] <= matrix_21; row2[2] <= matrix_22;

                    // Calculate row sums
                    sum0 <= row0[0] + row0[1] + row0[2];
                    sum1 <= row1[0] + row1[1] + row1[2];
                    sum2 <= row2[0] + row2[1] + row2[2];

                    next_state <= SORT;
                    sort_cycle <= 2'd0;
                    sort_iteration <= 2'd0;
                end

                SORT: begin
                    // Bubble sort implementation
                    if (sort_cycle < 2'd3) begin
                        if (sort_iteration < 2'd2) begin
                            // Compare and swap if needed
                            if (sort_iteration == 2'd0) begin
                                // Compare row0 and row1
                                if (sum0 > sum1) begin
                                    // Swap row0 and row1
                                    temp_row[0] <= row0[0]; temp_row[1] <= row0[1]; temp_row[2] <= row0[2];
                                    row0[0] <= row1[0]; row0[1] <= row1[1]; row0[2] <= row1[2];
                                    row1[0] <= temp_row[0]; row1[1] <= temp_row[1]; row1[2] <= temp_row[2];

                                    temp_sum <= sum0;
                                    sum0 <= sum1;
                                    sum1 <= temp_sum;
                                end
                            end else begin
                                // Compare row1 and row2
                                if (sum1 > sum2) begin
                                    // Swap row1 and row2
                                    temp_row[0] <= row1[0]; temp_row[1] <= row1[1]; temp_row[2] <= row1[2];
                                    row1[0] <= row2[0]; row1[1] <= row2[1]; row1[2] <= row2[2];
                                    row2[0] <= temp_row[0]; row2[1] <= temp_row[1]; row2[2] <= temp_row[2];

                                    temp_sum <= sum1;
                                    sum1 <= sum2;
                                    sum2 <= temp_sum;
                                end
                            end

                            sort_iteration <= sort_iteration + 2'd1;
                        end else begin
                            sort_iteration <= 2'd0;
                            sort_cycle <= sort_cycle + 2'd1;
                        end
                    end else begin
                        next_state <= OUTPUT;
                    end
                end

                OUTPUT: begin
                    // Pack the sorted matrix into result
                    result[3:0]   <= row0[0];
                    result[7:4]   <= row0[1];
                    result[11:8]  <= row0[2];
                    result[15:12] <= row1[0];
                    result[19:16] <= row1[1];
                    result[23:20] <= row1[2];
                    result[27:24] <= row2[0];
                    result[31:28] <= row2[1];
                    result[35:32] <= row2[2];

                    next_state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase

            // Safety: prevent infinite loops
            if (cycle_count >= MAX_CYCLES) begin
                next_state <= IDLE;
                done <= 1'b0;
            end else begin
                cycle_count <= cycle_count + 8'd1;
            end
        end
    end

endmodule