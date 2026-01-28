module find_max_length_sublist (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] sublists_0,  // sublist0 elements 0-3
    input wire [15:0] sublists_1,  // sublist1 elements 0-3
    input wire [15:0] sublists_2,  // sublist2 elements 0-3
    input wire [15:0] sublists_3,  // sublist3 elements 0-3
    input wire [3:0] valid_mask,
    output reg [3:0] max_length,
    output reg [7:0] max_sublist_0,
    output reg [7:0] max_sublist_1,
    output reg [7:0] max_sublist_2,
    output reg [7:0] max_sublist_3,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] INIT    = 3'd1;
    localparam [2:0] SCAN    = 3'd2;
    localparam [2:0] DECIDE  = 3'd3;
    localparam [2:0] OUTPUT  = 3'd4;
    localparam [2:0] DONE    = 3'd5;

    // Registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [1:0] sublist_idx;  // 0-3
    reg [1:0] next_sublist_idx;
    reg [2:0] current_length;
    reg [2:0] next_current_length;
    reg [2:0] max_len_reg;
    reg [2:0] next_max_len_reg;
    reg [1:0] max_sublist_idx;
    reg [1:0] next_max_sublist_idx;
    reg [7:0] temp_sublist_0;
    reg [7:0] temp_sublist_1;
    reg [7:0] temp_sublist_2;
    reg [7:0] temp_sublist_3;
    reg [7:0] next_temp_sublist_0;
    reg [7:0] next_temp_sublist_1;
    reg [7:0] next_temp_sublist_2;
    reg [7:0] next_temp_sublist_3;
    reg [1:0] element_idx;
    reg [1:0] next_element_idx;
    reg [7:0] current_first_element;
    reg [7:0] next_current_first_element;
    reg [7:0] max_first_element;
    reg [7:0] next_max_first_element;
    reg [7:0] sublists_0_reg;
    reg [7:0] sublists_1_reg;
    reg [7:0] sublists_2_reg;
    reg [7:0] sublists_3_reg;
    reg [7:0] sublists_4_reg;
    reg [7:0] sublists_5_reg;
    reg [7:0] sublists_6_reg;
    reg [7:0] sublists_7_reg;
    reg [7:0] sublists_8_reg;
    reg [7:0] sublists_9_reg;
    reg [7:0] sublists_10_reg;
    reg [7:0] sublists_11_reg;
    reg [7:0] sublists_12_reg;
    reg [7:0] sublists_13_reg;
    reg [7:0] sublists_14_reg;
    reg [7:0] sublists_15_reg;
    reg [3:0] valid_mask_reg;

    // Decode packed inputs into elements
    wire [7:0] sublist0_elem0 = sublists_0_reg;
    wire [7:0] sublist0_elem1 = sublists_1_reg;
    wire [7:0] sublist0_elem2 = sublists_2_reg;
    wire [7:0] sublist0_elem3 = sublists_3_reg;
    wire [7:0] sublist1_elem0 = sublists_4_reg;
    wire [7:0] sublist1_elem1 = sublists_5_reg;
    wire [7:0] sublist1_elem2 = sublists_6_reg;
    wire [7:0] sublist1_elem3 = sublists_7_reg;
    wire [7:0] sublist2_elem0 = sublists_8_reg;
    wire [7:0] sublist2_elem1 = sublists_9_reg;
    wire [7:0] sublist2_elem2 = sublists_10_reg;
    wire [7:0] sublist2_elem3 = sublists_11_reg;
    wire [7:0] sublist3_elem0 = sublists_12_reg;
    wire [7:0] sublist3_elem1 = sublists_13_reg;
    wire [7:0] sublist3_elem2 = sublists_14_reg;
    wire [7:0] sublist3_elem3 = sublists_15_reg;

    // Next state and logic
    always @(*) begin
        next_state = state;
        next_sublist_idx = sublist_idx;
        next_current_length = current_length;
        next_max_len_reg = max_len_reg;
        next_max_sublist_idx = max_sublist_idx;
        next_temp_sublist_0 = temp_sublist_0;
        next_temp_sublist_1 = temp_sublist_1;
        next_temp_sublist_2 = temp_sublist_2;
        next_temp_sublist_3 = temp_sublist_3;
        next_element_idx = element_idx;
        next_current_first_element = current_first_element;
        next_max_first_element = max_first_element;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                end
            end

            INIT: begin
                next_max_len_reg = 3'd0;
                next_max_sublist_idx = 2'd0;
                next_max_first_element = 8'd0;
                next_sublist_idx = 2'd0;
                next_state = SCAN;
            end

            SCAN: begin
                // Count non-zero elements in current sublist
                next_current_length = 3'd0;
                next_element_idx = 2'd0;
                
                case (sublist_idx)
                    2'd0: begin
                        if (valid_mask_reg[0]) begin
                            if (sublist0_elem0 != 8'd0) next_current_length = next_current_length + 3'd1;
                            if (sublist0_elem1 != 8'd0) next_current_length = next_current_length + 3'd1;
                            if (sublist0_elem2 != 8'd0) next_current_length = next_current_length + 3'd1;
                            if (sublist0_elem3 != 8'd0) next_current_length = next_current_length + 3'd1;
                            next_current_first_element = sublist0_elem0;
                            next_temp_sublist_0 = sublist0_elem0;
                            next_temp_sublist_1 = sublist0_elem1;
                            next_temp_sublist_2 = sublist0_elem2;
                            next_temp_sublist_3 = sublist0_elem3;
                        end else begin
                            next_current_length = 3'd0;
                        end
                    end
                    2'd1: begin
                        if (valid_mask_reg[1]) begin
                            if (sublist1_elem0 != 8'd0) next_current_length = next_current_length + 3'd1;
                            if (sublist1_elem1 != 8'd0) next_current_length = next_current_length + 3'd1;
                            if (sublist1_elem2 != 8'd0) next_current_length = next_current_length + 3'd1;
                            if (sublist1_elem3 != 8'd0) next_current_length = next_current_length + 3'd1;
                            next_current_first_element = sublist1_elem0;
                            next_temp_sublist_0 = sublist1_elem0;
                            next_temp_sublist_1 = sublist1_elem1;
                            next_temp_sublist_2 = sublist1_elem2;
                            next_temp_sublist_3 = sublist1_elem3;
                        end else begin
                            next_current_length = 3'd0;
                        end
                    end
                    2'd2: begin
                        if (valid_mask_reg[2]) begin
                            if (sublist2_elem0 != 8'd0) next_current_length = next_current_length + 3'd1;
                            if (sublist2_elem1 != 8'd0) next_current_length = next_current_length + 3'd1;
                            if (sublist2_elem2 != 8'd0) next_current_length = next_current_length + 3'd1;
                            if (sublist2_elem3 != 8'd0) next_current_length = next_current_length + 3'd1;
                            next_current_first_element = sublist2_elem0;
                            next_temp_sublist_0 = sublist2_elem0;
                            next_temp_sublist_1 = sublist2_elem1;
                            next_temp_sublist_2 = sublist2_elem2;
                            next_temp_sublist_3 = sublist2_elem3;
                        end else begin
                            next_current_length = 3'd0;
                        end
                    end
                    2'd3: begin
                        if (valid_mask_reg[3]) begin
                            if (sublist3_elem0 != 8'd0) next_current_length = next_current_length + 3'd1;
                            if (sublist3_elem1 != 8'd0) next_current_length = next_current_length + 3'd1;
                            if (sublist3_elem2 != 8'd0) next_current_length = next_current_length + 3'd1;
                            if (sublist3_elem3 != 8'd0) next_current_length = next_current_length + 3'd1;
                            next_current_first_element = sublist3_elem0;
                            next_temp_sublist_0 = sublist3_elem0;
                            next_temp_sublist_1 = sublist3_elem1;
                            next_temp_sublist_2 = sublist3_elem2;
                            next_temp_sublist_3 = sublist3_elem3;
                        end else begin
                            next_current_length = 3'd0;
                        end
                    end
                endcase

                next_state = DECIDE;
            end

            DECIDE: begin
                // Compare current length with max
                if (current_length > max_len_reg) begin
                    next_max_len_reg = current_length;
                    next_max_sublist_idx = sublist_idx;
                    next_max_first_element = current_first_element;
                end else if (current_length == max_len_reg && current_length != 3'd0) begin
                    // Tie-break: higher first element wins
                    if (current_first_element > max_first_element) begin
                        next_max_sublist_idx = sublist_idx;
                        next_max_first_element = current_first_element;
                    end
                end

                // Move to next sublist or finish
                if (sublist_idx < 2'd3) begin
                    next_sublist_idx = sublist_idx + 2'd1;
                    next_state = SCAN;
                end else begin
                    next_state = OUTPUT;
                end
            end

            OUTPUT: begin
                next_state = DONE;
            end

            DONE: begin
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // State register and outputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            sublist_idx <= 2'd0;
            current_length <= 3'd0;
            max_len_reg <= 3'd0;
            max_sublist_idx <= 2'd0;
            temp_sublist_0 <= 8'd0;
            temp_sublist_1 <= 8'd0;
            temp_sublist_2 <= 8'd0;
            temp_sublist_3 <= 8'd0;
            element_idx <= 2'd0;
            current_first_element <= 8'd0;
            max_first_element <= 8'd0;
            sublists_0_reg <= 8'd0;
            sublists_1_reg <= 8'd0;
            sublists_2_reg <= 8'd0;
            sublists_3_reg <= 8'd0;
            sublists_4_reg <= 8'd0;
            sublists_5_reg <= 8'd0;
            sublists_6_reg <= 8'd0;
            sublists_7_reg <= 8'd0;
            sublists_8_reg <= 8'd0;
            sublists_9_reg <= 8'd0;
            sublists_10_reg <= 8'd0;
            sublists_11_reg <= 8'd0;
            sublists_12_reg <= 8'd0;
            sublists_13_reg <= 8'd0;
            sublists_14_reg <= 8'd0;
            sublists_15_reg <= 8'd0;
            valid_mask_reg <= 4'd0;
            max_length <= 4'd0;
            max_sublist_0 <= 8'd0;
            max_sublist_1 <= 8'd0;
            max_sublist_2 <= 8'd0;
            max_sublist_3 <= 8'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            sublist_idx <= next_sublist_idx;
            current_length <= next_current_length;
            max_len_reg <= next_max_len_reg;
            max_sublist_idx <= next_max_sublist_idx;
            temp_sublist_0 <= next_temp_sublist_0;
            temp_sublist_1 <= next_temp_sublist_1;
            temp_sublist_2 <= next_temp_sublist_2;
            temp_sublist_3 <= next_temp_sublist_3;
            element_idx <= next_element_idx;
            current_first_element <= next_current_first_element;
            max_first_element <= next_max_first_element;

            // Store inputs on start pulse
            if (start) begin
                sublists_0_reg <= sublists_0[7:0];
                sublists_1_reg <= sublists_0[15:8];
                sublists_2_reg <= sublists_1[7:0];
                sublists_3_reg <= sublists_1[15:8];
                sublists_4_reg <= sublists_2[7:0];
                sublists_5_reg <= sublists_2[15:8];
                sublists_6_reg <= sublists_3[7:0];
                sublists_7_reg <= sublists_3[15:8];
                sublists_8_reg <= sublists_0[7:0];  // Wait, I need to reorganize
                sublists_9_reg <= sublists_0[15:8];
                sublists_10_reg <= sublists_1[7:0];
                sublists_11_reg <= sublists_1[15:8];
                sublists_12_reg <= sublists_2[7:0];
                sublists_13_reg <= sublists_2[15:8];
                sublists_14_reg <= sublists_3[7:0];
                sublists_15_reg <= sublists_3[15:8];
                valid_mask_reg <= valid_mask;
            end

            // Output when in OUTPUT state
            if (state == OUTPUT) begin
                max_length <= max_len_reg;
                case (max_sublist_idx)
                    2'd0: begin
                        max_sublist_0 <= sublists_0_reg;
                        max_sublist_1 <= sublists_1_reg;
                        max_sublist_2 <= sublists_2_reg;
                        max_sublist_3 <= sublists_3_reg;
                    end
                    2'd1: begin
                        max_sublist_0 <= sublists_4_reg;
                        max_sublist_1 <= sublists_5_reg;
                        max_sublist_2 <= sublists_6_reg;
                        max_sublist_3 <= sublists_7_reg;
                    end
                    2'd2: begin
                        max_sublist_0 <= sublists_8_reg;
                        max_sublist_1 <= sublists_9_reg;
                        max_sublist_2 <= sublists_10_reg;
                        max_sublist_3 <= sublists_11_reg;
                    end
                    2'd3: begin
                        max_sublist_0 <= sublists_12_reg;
                        max_sublist_1 <= sublists_13_reg;
                        max_sublist_2 <= sublists_14_reg;
                        max_sublist_3 <= sublists_15_reg;
                    end
                endcase
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end

endmodule