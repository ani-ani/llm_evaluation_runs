module sort_even(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    input [7:0] arr_6,
    input [7:0] arr_7,
    input [7:0] arr_8,
    input [7:0] arr_9,
    input [7:0] arr_10,
    input [7:0] arr_11,
    input [7:0] arr_12,
    input [7:0] arr_13,
    input [7:0] arr_14,
    input [7:0] arr_15,
    input [3:0] len,
    output reg [7:0] result_0,
    output reg [7:0] result_1,
    output reg [7:0] result_2,
    output reg [7:0] result_3,
    output reg [7:0] result_4,
    output reg [7:0] result_5,
    output reg [7:0] result_6,
    output reg [7:0] result_7,
    output reg [7:0] result_8,
    output reg [7:0] result_9,
    output reg [7:0] result_10,
    output reg [7:0] result_11,
    output reg [7:0] result_12,
    output reg [7:0] result_13,
    output reg [7:0] result_14,
    output reg [7:0] result_15,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] EXTRACT = 3'd1;
    localparam [2:0] SORT = 3'd2;
    localparam [2:0] ASSIGN = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // Internal registers for input storage
    reg [7:0] stored_arr_0, stored_arr_1, stored_arr_2, stored_arr_3;
    reg [7:0] stored_arr_4, stored_arr_5, stored_arr_6, stored_arr_7;
    reg [7:0] stored_arr_8, stored_arr_9, stored_arr_10, stored_arr_11;
    reg [7:0] stored_arr_12, stored_arr_13, stored_arr_14, stored_arr_15;
    reg [3:0] stored_len;

    // Temporary even array (max 8 elements for 16 total)
    reg [7:0] even_arr_0, even_arr_1, even_arr_2, even_arr_3;
    reg [7:0] even_arr_4, even_arr_5, even_arr_6, even_arr_7;
    reg [3:0] even_count;

    // Sorting state machine variables
    reg [3:0] i_idx, j_idx;  // For bubble sort
    reg [3:0] pass_count;    // Track bubble sort passes
    reg [3:0] num_even;      // Number of even elements
    reg swap_temp;           // Flag for swap

    // State machine
    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Reset all output registers
            result_0 <= 8'd0;
            result_1 <= 8'd0;
            result_2 <= 8'd0;
            result_3 <= 8'd0;
            result_4 <= 8'd0;
            result_5 <= 8'd0;
            result_6 <= 8'd0;
            result_7 <= 8'd0;
            result_8 <= 8'd0;
            result_9 <= 8'd0;
            result_10 <= 8'd0;
            result_11 <= 8'd0;
            result_12 <= 8'd0;
            result_13 <= 8'd0;
            result_14 <= 8'd0;
            result_15 <= 8'd0;
            
            // Reset internal state
            stored_arr_0 <= 8'd0;
            stored_arr_1 <= 8'd0;
            stored_arr_2 <= 8'd0;
            stored_arr_3 <= 8'd0;
            stored_arr_4 <= 8'd0;
            stored_arr_5 <= 8'd0;
            stored_arr_6 <= 8'd0;
            stored_arr_7 <= 8'd0;
            stored_arr_8 <= 8'd0;
            stored_arr_9 <= 8'd0;
            stored_arr_10 <= 8'd0;
            stored_arr_11 <= 8'd0;
            stored_arr_12 <= 8'd0;
            stored_arr_13 <= 8'd0;
            stored_arr_14 <= 8'd0;
            stored_arr_15 <= 8'd0;
            stored_len <= 4'd0;
            
            even_arr_0 <= 8'd0;
            even_arr_1 <= 8'd0;
            even_arr_2 <= 8'd0;
            even_arr_3 <= 8'd0;
            even_arr_4 <= 8'd0;
            even_arr_5 <= 8'd0;
            even_arr_6 <= 8'd0;
            even_arr_7 <= 8'd0;
            even_count <= 4'd0;
            
            i_idx <= 4'd0;
            j_idx <= 4'd0;
            pass_count <= 4'd0;
            num_even <= 4'd0;
            swap_temp <= 1'b0;
            
        end else begin
            cycle_count <= cycle_count + 8'd1;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    
                    if (start) begin
                        // Store input array
                        stored_arr_0 <= arr_0;
                        stored_arr_1 <= arr_1;
                        stored_arr_2 <= arr_2;
                        stored_arr_3 <= arr_3;
                        stored_arr_4 <= arr_4;
                        stored_arr_5 <= arr_5;
                        stored_arr_6 <= arr_6;
                        stored_arr_7 <= arr_7;
                        stored_arr_8 <= arr_8;
                        stored_arr_9 <= arr_9;
                        stored_arr_10 <= arr_10;
                        stored_arr_11 <= arr_11;
                        stored_arr_12 <= arr_12;
                        stored_arr_13 <= arr_13;
                        stored_arr_14 <= arr_14;
                        stored_arr_15 <= arr_15;
                        stored_len <= len;
                        
                        // Initialize for extraction
                        i_idx <= 4'd0;
                        even_count <= 4'd0;
                        state <= EXTRACT;
                    end
                end
                
                EXTRACT: begin
                    if (i_idx < stored_len) begin
                        // Check if current index is even (i_idx % 2 == 0)
                        if (i_idx[0] == 1'b0) begin
                            // Store even element
                            case (even_count)
                                4'd0: even_arr_0 <= (i_idx == 4'd0) ? stored_arr_0 :
                                                      (i_idx == 4'd2) ? stored_arr_2 :
                                                      (i_idx == 4'd4) ? stored_arr_4 :
                                                      (i_idx == 4'd6) ? stored_arr_6 :
                                                      (i_idx == 4'd8) ? stored_arr_8 :
                                                      (i_idx == 4'd10) ? stored_arr_10 :
                                                      (i_idx == 4'd12) ? stored_arr_12 :
                                                      stored_arr_14;
                                4'd1: even_arr_1 <= (i_idx == 4'd2) ? stored_arr_2 :
                                                      (i_idx == 4'd4) ? stored_arr_4 :
                                                      (i_idx == 4'd6) ? stored_arr_6 :
                                                      (i_idx == 4'd8) ? stored_arr_8 :
                                                      (i_idx == 4'd10) ? stored_arr_10 :
                                                      (i_idx == 4'd12) ? stored_arr_12 :
                                                      stored_arr_14;
                                4'd2: even_arr_2 <= (i_idx == 4'd4) ? stored_arr_4 :
                                                      (i_idx == 4'd6) ? stored_arr_6 :
                                                      (i_idx == 4'd8) ? stored_arr_8 :
                                                      (i_idx == 4'd10) ? stored_arr_10 :
                                                      (i_idx == 4'd12) ? stored_arr_12 :
                                                      stored_arr_14;
                                4'd3: even_arr_3 <= (i_idx == 4'd6) ? stored_arr_6 :
                                                      (i_idx == 4'd8) ? stored_arr_8 :
                                                      (i_idx == 4'd10) ? stored_arr_10 :
                                                      (i_idx == 4'd12) ? stored_arr_12 :
                                                      stored_arr_14;
                                4'd4: even_arr_4 <= (i_idx == 4'd8) ? stored_arr_8 :
                                                      (i_idx == 4'd10) ? stored_arr_10 :
                                                      (i_idx == 4'd12) ? stored_arr_12 :
                                                      stored_arr_14;
                                4'd5: even_arr_5 <= (i_idx == 4'd10) ? stored_arr_10 :
                                                      (i_idx == 4'd12) ? stored_arr_12 :
                                                      stored_arr_14;
                                4'd6: even_arr_6 <= (i_idx == 4'd12) ? stored_arr_12 :
                                                      stored_arr_14;
                                4'd7: even_arr_7 <= stored_arr_14;
                            endcase
                            even_count <= even_count + 4'd1;
                        end
                        i_idx <= i_idx + 4'd1;
                    end else begin
                        num_even <= even_count;
                        if (even_count > 4'd1) begin
                            // Initialize bubble sort
                            i_idx <= 4'd0;
                            j_idx <= 4'd0;
                            pass_count <= 4'd0;
                            state <= SORT;
                        end else begin
                            // 0 or 1 even elements, no sorting needed
                            state <= ASSIGN;
                        end
                    end
                end
                
                SORT: begin
                    if (pass_count < num_even - 4'd1) begin
                        if (j_idx < num_even - 4'd1 - pass_count) begin
                            // Compare and potentially swap
                            case (j_idx)
                                4'd0: swap_temp <= (even_arr_0 > even_arr_1);
                                4'd1: swap_temp <= (even_arr_1 > even_arr_2);
                                4'd2: swap_temp <= (even_arr_2 > even_arr_3);
                                4'd3: swap_temp <= (even_arr_3 > even_arr_4);
                                4'd4: swap_temp <= (even_arr_4 > even_arr_5);
                                4'd5: swap_temp <= (even_arr_5 > even_arr_6);
                                4'd6: swap_temp <= (even_arr_6 > even_arr_7);
                                default: swap_temp <= 1'b0;
                            endcase
                            
                            if (swap_temp) begin
                                // Swap elements
                                case (j_idx)
                                    4'd0: begin
                                        even_arr_0 <= even_arr_1;
                                        even_arr_1 <= even_arr_0;
                                    end
                                    4'd1: begin
                                        even_arr_1 <= even_arr_2;
                                        even_arr_2 <= even_arr_1;
                                    end
                                    4'd2: begin
                                        even_arr_2 <= even_arr_3;
                                        even_arr_3 <= even_arr_2;
                                    end
                                    4'd3: begin
                                        even_arr_3 <= even_arr_4;
                                        even_arr_4 <= even_arr_3;
                                    end
                                    4'd4: begin
                                        even_arr_4 <= even_arr_5;
                                        even_arr_5 <= even_arr_4;
                                    end
                                    4'd5: begin
                                        even_arr_5 <= even_arr_6;
                                        even_arr_6 <= even_arr_5;
                                    end
                                    4'd6: begin
                                        even_arr_6 <= even_arr_7;
                                        even_arr_7 <= even_arr_6;
                                    end
                                endcase
                            end
                            j_idx <= j_idx + 4'd1;
                        end else begin
                            j_idx <= 4'd0;
                            pass_count <= pass_count + 4'd1;
                        end
                    end else begin
                        state <= ASSIGN;
                        i_idx <= 4'd0;  // Use for output assignment
                    end
                end
                
                ASSIGN: begin
                    // Copy stored odd values and sorted even values to result
                    if (i_idx < stored_len) begin
                        if (i_idx[0] == 1'b0) begin
                            // Even index - place sorted value
                            case (i_idx)
                                4'd0: result_0 <= even_arr_0;
                                4'd2: result_2 <= (num_even > 4'd1) ? even_arr_1 : stored_arr_2;
                                4'd4: result_4 <= (num_even > 4'd2) ? even_arr_2 : stored_arr_4;
                                4'd6: result_6 <= (num_even > 4'd3) ? even_arr_3 : stored_arr_6;
                                4'd8: result_8 <= (num_even > 4'd4) ? even_arr_4 : stored_arr_8;
                                4'd10: result_10 <= (num_even > 4'd5) ? even_arr_5 : stored_arr_10;
                                4'd12: result_12 <= (num_even > 4'd6) ? even_arr_6 : stored_arr_12;
                                4'd14: result_14 <= (num_even > 4'd7) ? even_arr_7 : stored_arr_14;
                            endcase
                        end else begin
                            // Odd index - copy from stored
                            case (i_idx)
                                4'd1: result_1 <= stored_arr_1;
                                4'd3: result_3 <= stored_arr_3;
                                4'd5: result_5 <= stored_arr_5;
                                4'd7: result_7 <= stored_arr_7;
                                4'd9: result_9 <= stored_arr_9;
                                4'd11: result_11 <= stored_arr_11;
                                4'd13: result_13 <= stored_arr_13;
                                4'd15: result_15 <= stored_arr_15;
                            endcase
                        end
                        i_idx <= i_idx + 4'd1;
                    end else begin
                        state <= DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            // Safety timeout
            if (cycle_count >= MAX_CYCLES && state != IDLE && state != DONE_STATE) begin
                state <= DONE_STATE;
            end
        end
    end

endmodule