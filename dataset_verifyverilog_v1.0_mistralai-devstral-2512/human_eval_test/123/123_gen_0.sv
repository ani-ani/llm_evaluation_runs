module CollatzOddSorter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] n_in,
    output reg [15:0] result_0,
    output reg [15:0] result_1,
    output reg [15:0] result_2,
    output reg [15:0] result_3,
    output reg [15:0] result_4,
    output reg [15:0] result_5,
    output reg [15:0] result_6,
    output reg [15:0] result_7,
    output reg [15:0] result_8,
    output reg [15:0] result_9,
    output reg [15:0] result_10,
    output reg [15:0] result_11,
    output reg [15:0] result_12,
    output reg [15:0] result_13,
    output reg [15:0] result_14,
    output reg [15:0] result_15,
    output reg [3:0] result_len,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] CALCULATE = 2'd1;
    localparam [1:0] SORT     = 2'd2;
    localparam [1:0] FINISH   = 2'd3;

    // Internal registers
    reg [1:0] state;
    reg [15:0] n_reg;
    reg [7:0] step_count;
    reg [3:0] odd_count;
    reg [3:0] sort_i;
    reg [3:0] sort_j;

    // Array storage for odd numbers
    reg [15:0] odd_array_0;
    reg [15:0] odd_array_1;
    reg [15:0] odd_array_2;
    reg [15:0] odd_array_3;
    reg [15:0] odd_array_4;
    reg [15:0] odd_array_5;
    reg [15:0] odd_array_6;
    reg [15:0] odd_array_7;
    reg [15:0] odd_array_8;
    reg [15:0] odd_array_9;
    reg [15:0] odd_array_10;
    reg [15:0] odd_array_11;
    reg [15:0] odd_array_12;
    reg [15:0] odd_array_13;
    reg [15:0] odd_array_14;
    reg [15:0] odd_array_15;

    // Cycle counter to prevent infinite loops
    reg [10:0] cycle_count;
    localparam [10:0] MAX_CYCLES = 11'd2048;

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            n_reg <= 16'd0;
            step_count <= 8'd0;
            odd_count <= 4'd0;
            sort_i <= 4'd0;
            sort_j <= 4'd0;
            cycle_count <= 11'd0;
            done <= 1'b0;
            result_len <= 4'd0;

            // Initialize array
            odd_array_0 <= 16'd0;
            odd_array_1 <= 16'd0;
            odd_array_2 <= 16'd0;
            odd_array_3 <= 16'd0;
            odd_array_4 <= 16'd0;
            odd_array_5 <= 16'd0;
            odd_array_6 <= 16'd0;
            odd_array_7 <= 16'd0;
            odd_array_8 <= 16'd0;
            odd_array_9 <= 16'd0;
            odd_array_10 <= 16'd0;
            odd_array_11 <= 16'd0;
            odd_array_12 <= 16'd0;
            odd_array_13 <= 16'd0;
            odd_array_14 <= 16'd0;
            odd_array_15 <= 16'd0;

            // Initialize outputs
            result_0 <= 16'd0;
            result_1 <= 16'd0;
            result_2 <= 16'd0;
            result_3 <= 16'd0;
            result_4 <= 16'd0;
            result_5 <= 16'd0;
            result_6 <= 16'd0;
            result_7 <= 16'd0;
            result_8 <= 16'd0;
            result_9 <= 16'd0;
            result_10 <= 16'd0;
            result_11 <= 16'd0;
            result_12 <= 16'd0;
            result_13 <= 16'd0;
            result_14 <= 16'd0;
            result_15 <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 11'd0;
                    if (start) begin
                        state <= CALCULATE;
                        n_reg <= n_in;
                        step_count <= 8'd0;
                        odd_count <= 4'd0;
                        sort_i <= 4'd0;
                        sort_j <= 4'd0;
                    end
                end

                CALCULATE: begin
                    cycle_count <= cycle_count + 11'd1;

                    // Check if n is odd
                    if (n_reg[0] == 1'b1) begin
                        // Store odd number if we have space
                        if (odd_count < 4'd16) begin
                            case (odd_count)
                                4'd0: odd_array_0 <= n_reg;
                                4'd1: odd_array_1 <= n_reg;
                                4'd2: odd_array_2 <= n_reg;
                                4'd3: odd_array_3 <= n_reg;
                                4'd4: odd_array_4 <= n_reg;
                                4'd5: odd_array_5 <= n_reg;
                                4'd6: odd_array_6 <= n_reg;
                                4'd7: odd_array_7 <= n_reg;
                                4'd8: odd_array_8 <= n_reg;
                                4'd9: odd_array_9 <= n_reg;
                                4'd10: odd_array_10 <= n_reg;
                                4'd11: odd_array_11 <= n_reg;
                                4'd12: odd_array_12 <= n_reg;
                                4'd13: odd_array_13 <= n_reg;
                                4'd14: odd_array_14 <= n_reg;
                                4'd15: odd_array_15 <= n_reg;
                            endcase
                            odd_count <= odd_count + 4'd1;
                        end
                    end

                    // Update n for next step
                    if (n_reg == 16'd1) begin
                        state <= SORT;
                    end else if (step_count >= 8'd255 || cycle_count >= MAX_CYCLES - 11'd512) begin
                        state <= SORT;
                    end else begin
                        if (n_reg[0] == 1'b0) begin
                            n_reg <= n_reg >> 1;
                        end else begin
                            n_reg <= (n_reg * 3'd3) + 16'd1;
                        end
                        step_count <= step_count + 8'd1;
                    end
                end

                SORT: begin
                    cycle_count <= cycle_count + 11'd1;

                    // Bubble sort implementation
                    if (sort_i < odd_count - 4'd1) begin
                        if (sort_j < odd_count - sort_i - 4'd1) begin
                            // Compare and swap
                            case (sort_j)
                                4'd0: begin
                                    if (odd_array_0 > odd_array_1) begin
                                        reg [15:0] temp = odd_array_0;
                                        odd_array_0 <= odd_array_1;
                                        odd_array_1 <= temp;
                                    end
                                end
                                4'd1: begin
                                    if (odd_array_1 > odd_array_2) begin
                                        reg [15:0] temp = odd_array_1;
                                        odd_array_1 <= odd_array_2;
                                        odd_array_2 <= temp;
                                    end
                                end
                                4'd2: begin
                                    if (odd_array_2 > odd_array_3) begin
                                        reg [15:0] temp = odd_array_2;
                                        odd_array_2 <= odd_array_3;
                                        odd_array_3 <= temp;
                                    end
                                end
                                4'd3: begin
                                    if (odd_array_3 > odd_array_4) begin
                                        reg [15:0] temp = odd_array_3;
                                        odd_array_3 <= odd_array_4;
                                        odd_array_4 <= temp;
                                    end
                                end
                                4'd4: begin
                                    if (odd_array_4 > odd_array_5) begin
                                        reg [15:0] temp = odd_array_4;
                                        odd_array_4 <= odd_array_5;
                                        odd_array_5 <= temp;
                                    end
                                end
                                4'd5: begin
                                    if (odd_array_5 > odd_array_6) begin
                                        reg [15:0] temp = odd_array_5;
                                        odd_array_5 <= odd_array_6;
                                        odd_array_6 <= temp;
                                    end
                                end
                                4'd6: begin
                                    if (odd_array_6 > odd_array_7) begin
                                        reg [15:0] temp = odd_array_6;
                                        odd_array_6 <= odd_array_7;
                                        odd_array_7 <= temp;
                                    end
                                end
                                4'd7: begin
                                    if (odd_array_7 > odd_array_8) begin
                                        reg [15:0] temp = odd_array_7;
                                        odd_array_7 <= odd_array_8;
                                        odd_array_8 <= temp;
                                    end
                                end
                                4'd8: begin
                                    if (odd_array_8 > odd_array_9) begin
                                        reg [15:0] temp = odd_array_8;
                                        odd_array_8 <= odd_array_9;
                                        odd_array_9 <= temp;
                                    end
                                end
                                4'd9: begin
                                    if (odd_array_9 > odd_array_10) begin
                                        reg [15:0] temp = odd_array_9;
                                        odd_array_9 <= odd_array_10;
                                        odd_array_10 <= temp;
                                    end
                                end
                                4'd10: begin
                                    if (odd_array_10 > odd_array_11) begin
                                        reg [15:0] temp = odd_array_10;
                                        odd_array_10 <= odd_array_11;
                                        odd_array_11 <= temp;
                                    end
                                end
                                4'd11: begin
                                    if (odd_array_11 > odd_array_12) begin
                                        reg [15:0] temp = odd_array_11;
                                        odd_array_11 <= odd_array_12;
                                        odd_array_12 <= temp;
                                    end
                                end
                                4'd12: begin
                                    if (odd_array_12 > odd_array_13) begin
                                        reg [15:0] temp = odd_array_12;
                                        odd_array_12 <= odd_array_13;
                                        odd_array_13 <= temp;
                                    end
                                end
                                4'd13: begin
                                    if (odd_array_13 > odd_array_14) begin
                                        reg [15:0] temp = odd_array_13;
                                        odd_array_13 <= odd_array_14;
                                        odd_array_14 <= temp;
                                    end
                                end
                                4'd14: begin
                                    if (odd_array_14 > odd_array_15) begin
                                        reg [15:0] temp = odd_array_14;
                                        odd_array_14 <= odd_array_15;
                                        odd_array_15 <= temp;
                                    end
                                end
                            endcase
                            sort_j <= sort_j + 4'd1;
                        end else begin
                            sort_j <= 4'd0;
                            sort_i <= sort_i + 4'd1;
                        end
                    end else begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    result_len <= odd_count;

                    // Copy sorted array to outputs
                    result_0 <= odd_array_0;
                    result_1 <= odd_array_1;
                    result_2 <= odd_array_2;
                    result_3 <= odd_array_3;
                    result_4 <= odd_array_4;
                    result_5 <= odd_array_5;
                    result_6 <= odd_array_6;
                    result_7 <= odd_array_7;
                    result_8 <= odd_array_8;
                    result_9 <= odd_array_9;
                    result_10 <= odd_array_10;
                    result_11 <= odd_array_11;
                    result_12 <= odd_array_12;
                    result_13 <= odd_array_13;
                    result_14 <= odd_array_14;
                    result_15 <= odd_array_15;

                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule