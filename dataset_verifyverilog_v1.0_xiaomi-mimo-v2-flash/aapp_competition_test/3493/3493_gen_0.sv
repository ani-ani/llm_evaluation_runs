module MaximumDisjointMatchings (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire adj_0_0, adj_0_1, adj_0_2, adj_0_3, adj_0_4, adj_0_5, adj_0_6, adj_0_7,
    input wire adj_0_8, adj_0_9, adj_0_10, adj_0_11, adj_0_12, adj_0_13, adj_0_14, adj_0_15,
    input wire adj_1_0, adj_1_1, adj_1_2, adj_1_3, adj_1_4, adj_1_5, adj_1_6, adj_1_7,
    input wire adj_1_8, adj_1_9, adj_1_10, adj_1_11, adj_1_12, adj_1_13, adj_1_14, adj_1_15,
    input wire adj_2_0, adj_2_1, adj_2_2, adj_2_3, adj_2_4, adj_2_5, adj_2_6, adj_2_7,
    input wire adj_2_8, adj_2_9, adj_2_10, adj_2_11, adj_2_12, adj_2_13, adj_2_14, adj_2_15,
    input wire adj_3_0, adj_3_1, adj_3_2, adj_3_3, adj_3_4, adj_3_5, adj_3_6, adj_3_7,
    input wire adj_3_8, adj_3_9, adj_3_10, adj_3_11, adj_3_12, adj_3_13, adj_3_14, adj_3_15,
    input wire adj_4_0, adj_4_1, adj_4_2, adj_4_3, adj_4_4, adj_4_5, adj_4_6, adj_4_7,
    input wire adj_4_8, adj_4_9, adj_4_10, adj_4_11, adj_4_12, adj_4_13, adj_4_14, adj_4_15,
    input wire adj_5_0, adj_5_1, adj_5_2, adj_5_3, adj_5_4, adj_5_5, adj_5_6, adj_5_7,
    input wire adj_5_8, adj_5_9, adj_5_10, adj_5_11, adj_5_12, adj_5_13, adj_5_14, adj_5_15,
    input wire adj_6_0, adj_6_1, adj_6_2, adj_6_3, adj_6_4, adj_6_5, adj_6_6, adj_6_7,
    input wire adj_6_8, adj_6_9, adj_6_10, adj_6_11, adj_6_12, adj_6_13, adj_6_14, adj_6_15,
    input wire adj_7_0, adj_7_1, adj_7_2, adj_7_3, adj_7_4, adj_7_5, adj_7_6, adj_7_7,
    input wire adj_7_8, adj_7_9, adj_7_10, adj_7_11, adj_7_12, adj_7_13, adj_7_14, adj_7_15,
    input wire adj_8_0, adj_8_1, adj_8_2, adj_8_3, adj_8_4, adj_8_5, adj_8_6, adj_8_7,
    input wire adj_8_8, adj_8_9, adj_8_10, adj_8_11, adj_8_12, adj_8_13, adj_8_14, adj_8_15,
    input wire adj_9_0, adj_9_1, adj_9_2, adj_9_3, adj_9_4, adj_9_5, adj_9_6, adj_9_7,
    input wire adj_9_8, adj_9_9, adj_9_10, adj_9_11, adj_9_12, adj_9_13, adj_9_14, adj_9_15,
    input wire adj_10_0, adj_10_1, adj_10_2, adj_10_3, adj_10_4, adj_10_5, adj_10_6, adj_10_7,
    input wire adj_10_8, adj_10_9, adj_10_10, adj_10_11, adj_10_12, adj_10_13, adj_10_14, adj_10_15,
    input wire adj_11_0, adj_11_1, adj_11_2, adj_11_3, adj_11_4, adj_11_5, adj_11_6, adj_11_7,
    input wire adj_11_8, adj_11_9, adj_11_10, adj_11_11, adj_11_12, adj_11_13, adj_11_14, adj_11_15,
    input wire adj_12_0, adj_12_1, adj_12_2, adj_12_3, adj_12_4, adj_12_5, adj_12_6, adj_12_7,
    input wire adj_12_8, adj_12_9, adj_12_10, adj_12_11, adj_12_12, adj_12_13, adj_12_14, adj_12_15,
    input wire adj_13_0, adj_13_1, adj_13_2, adj_13_3, adj_13_4, adj_13_5, adj_13_6, adj_13_7,
    input wire adj_13_8, adj_13_9, adj_13_10, adj_13_11, adj_13_12, adj_13_13, adj_13_14, adj_13_15,
    input wire adj_14_0, adj_14_1, adj_14_2, adj_14_3, adj_14_4, adj_14_5, adj_14_6, adj_14_7,
    input wire adj_14_8, adj_14_9, adj_14_10, adj_14_11, adj_14_12, adj_14_13, adj_14_14, adj_14_15,
    input wire adj_15_0, adj_15_1, adj_15_2, adj_15_3, adj_15_4, adj_15_5, adj_15_6, adj_15_7,
    input wire adj_15_8, adj_15_9, adj_15_10, adj_15_11, adj_15_12, adj_15_13, adj_15_14, adj_15_15,
    output reg done,
    output reg [3:0] k,
    output reg [3:0] matching_0_0, matching_0_1, matching_0_2, matching_0_3,
    output reg [3:0] matching_0_4, matching_0_5, matching_0_6, matching_0_7,
    output reg [3:0] matching_0_8, matching_0_9, matching_0_10, matching_0_11,
    output reg [3:0] matching_0_12, matching_0_13, matching_0_14, matching_0_15,
    output reg [3:0] matching_1_0, matching_1_1, matching_1_2, matching_1_3,
    output reg [3:0] matching_1_4, matching_1_5, matching_1_6, matching_1_7,
    output reg [3:0] matching_1_8, matching_1_9, matching_1_10, matching_1_11,
    output reg [3:0] matching_1_12, matching_1_13, matching_1_14, matching_1_15,
    output reg [3:0] matching_2_0, matching_2_1, matching_2_2, matching_2_3,
    output reg [3:0] matching_2_4, matching_2_5, matching_2_6, matching_2_7,
    output reg [3:0] matching_2_8, matching_2_9, matching_2_10, matching_2_11,
    output reg [3:0] matching_2_12, matching_2_13, matching_2_14, matching_2_15,
    output reg [3:0] matching_3_0, matching_3_1, matching_3_2, matching_3_3,
    output reg [3:0] matching_3_4, matching_3_5, matching_3_6, matching_3_7,
    output reg [3:0] matching_3_8, matching_3_9, matching_3_10, matching_3_11,
    output reg [3:0] matching_3_12, matching_3_13, matching_3_14, matching_3_15,
    output reg [3:0] matching_4_0, matching_4_1, matching_4_2, matching_4_3,
    output reg [3:0] matching_4_4, matching_4_5, matching_4_6, matching_4_7,
    output reg [3:0] matching_4_8, matching_4_9, matching_4_10, matching_4_11,
    output reg [3:0] matching_4_12, matching_4_13, matching_4_14, matching_4_15,
    output reg [3:0] matching_5_0, matching_5_1, matching_5_2, matching_5_3,
    output reg [3:0] matching_5_4, matching_5_5, matching_5_6, matching_5_7,
    output reg [3:0] matching_5_8, matching_5_9, matching_5_10, matching_5_11,
    output reg [3:0] matching_5_12, matching_5_13, matching_5_14, matching_5_15,
    output reg [3:0] matching_6_0, matching_6_1, matching_6_2, matching_6_3,
    output reg [3:0] matching_6_4, matching_6_5, matching_6_6, matching_6_7,
    output reg [3:0] matching_6_8, matching_6_9, matching_6_10, matching_6_11,
    output reg [3:0] matching_6_12, matching_6_13, matching_6_14, matching_6_15,
    output reg [3:0] matching_7_0, matching_7_1, matching_7_2, matching_7_3,
    output reg [3:0] matching_7_4, matching_7_5, matching_7_6, matching_7_7,
    output reg [3:0] matching_7_8, matching_7_9, matching_7_10, matching_7_11,
    output reg [3:0] matching_7_12, matching_7_13, matching_7_14, matching_7_15,
    output reg [3:0] matching_8_0, matching_8_1, matching_8_2, matching_8_3,
    output reg [3:0] matching_8_4, matching_8_5, matching_8_6, matching_8_7,
    output reg [3:0] matching_8_8, matching_8_9, matching_8_10, matching_8_11,
    output reg [3:0] matching_8_12, matching_8_13, matching_8_14, matching_8_15,
    output reg [3:0] matching_9_0, matching_9_1, matching_9_2, matching_9_3,
    output reg [3:0] matching_9_4, matching_9_5, matching_9_6, matching_9_7,
    output reg [3:0] matching_9_8, matching_9_9, matching_9_10, matching_9_11,
    output reg [3:0] matching_9_12, matching_9_13, matching_9_14, matching_9_15,
    output reg [3:0] matching_10_0, matching_10_1, matching_10_2, matching_10_3,
    output reg [3:0] matching_10_4, matching_10_5, matching_10_6, matching_10_7,
    output reg [3:0] matching_10_8, matching_10_9, matching_10_10, matching_10_11,
    output reg [3:0] matching_10_12, matching_10_13, matching_10_14, matching_10_15,
    output reg [3:0] matching_11_0, matching_11_1, matching_11_2, matching_11_3,
    output reg [3:0] matching_11_4, matching_11_5, matching_11_6, matching_11_7,
    output reg [3:0] matching_11_8, matching_11_9, matching_11_10, matching_11_11,
    output reg [3:0] matching_11_12, matching_11_13, matching_11_14, matching_11_15,
    output reg [3:0] matching_12_0, matching_12_1, matching_12_2, matching_12_3,
    output reg [3:0] matching_12_4, matching_12_5, matching_12_6, matching_12_7,
    output reg [3:0] matching_12_8, matching_12_9, matching_12_10, matching_12_11,
    output reg [3:0] matching_12_12, matching_12_13, matching_12_14, matching_12_15,
    output reg [3:0] matching_13_0, matching_13_1, matching_13_2, matching_13_3,
    output reg [3:0] matching_13_4, matching_13_5, matching_13_6, matching_13_7,
    output reg [3:0] matching_13_8, matching_13_9, matching_13_10, matching_13_11,
    output reg [3:0] matching_13_12, matching_13_13, matching_13_14, matching_13_15,
    output reg [3:0] matching_14_0, matching_14_1, matching_14_2, matching_14_3,
    output reg [3:0] matching_14_4, matching_14_5, matching_14_6, matching_14_7,
    output reg [3:0] matching_14_8, matching_14_9, matching_14_10, matching_14_11,
    output reg [3:0] matching_14_12, matching_14_13, matching_14_14, matching_14_15,
    output reg [3:0] matching_15_0, matching_15_1, matching_15_2, matching_15_3,
    output reg [3:0] matching_15_4, matching_15_5, matching_15_6, matching_15_7,
    output reg [3:0] matching_15_8, matching_15_9, matching_15_10, matching_15_11,
    output reg [3:0] matching_15_12, matching_15_13, matching_15_14, matching_15_15
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] STORE_INPUT = 3'd1;
    localparam [2:0] COMPUTE_MATCHING = 3'd2;
    localparam [2:0] CHECK_MATCH = 3'd3;
    localparam [2:0] STORE_MATCHING = 3'd4;
    localparam [2:0] REMOVE_EDGES = 3'd5;
    localparam [2:0] DONE_STATE = 3'd6;

    reg [2:0] state;
    reg [2:0] next_state;
    
    // Timing and control
    reg [31:0] cycle_count;
    localparam [31:0] MAX_CYCLES = 32'd5000;
    reg [3:0] current_matching_idx;
    reg [3:0] current_person;
    reg [3:0] current_button;
    reg [3:0] matching_size;
    reg found_matching;
    
    // Fixed-size storage for adjacency matrix (16x16)
    reg [15:0] adj_reg_0, adj_reg_1, adj_reg_2, adj_reg_3;
    reg [15:0] adj_reg_4, adj_reg_5, adj_reg_6, adj_reg_7;
    reg [15:0] adj_reg_8, adj_reg_9, adj_reg_10, adj_reg_11;
    reg [15:0] adj_reg_12, adj_reg_13, adj_reg_14, adj_reg_15;
    
    // Temporary storage for current matching being computed
    reg [3:0] temp_match_0, temp_match_1, temp_match_2, temp_match_3;
    reg [3:0] temp_match_4, temp_match_5, temp_match_6, temp_match_7;
    reg [3:0] temp_match_8, temp_match_9, temp_match_10, temp_match_11;
    reg [3:0] temp_match_12, temp_match_13, temp_match_14, temp_match_15;
    
    // Button-to-person mapping (for greedy matching)
    reg [3:0] btn_match_0, btn_match_1, btn_match_2, btn_match_3;
    reg [3:0] btn_match_4, btn_match_5, btn_match_6, btn_match_7;
    reg [3:0] btn_match_8, btn_match_9, btn_match_10, btn_match_11;
    reg [3:0] btn_match_12, btn_match_13, btn_match_14, btn_match_15;
    
    // Matched flags
    reg matched_0, matched_1, matched_2, matched_3;
    reg matched_4, matched_5, matched_6, matched_7;
    reg matched_8, matched_9, matched_10, matched_11;
    reg matched_12, matched_13, matched_14, matched_15;
    
    // Flags
    reg n_stored;
    reg temp_matching_valid;
    
    integer i, j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            k <= 4'd0;
            cycle_count <= 32'd0;
            current_matching_idx <= 4'd0;
            current_person <= 4'd0;
            current_button <= 4'd0;
            matching_size <= 4'd0;
            found_matching <= 1'b0;
            n_stored <= 1'b0;
            temp_matching_valid <= 1'b0;
            
            adj_reg_0 <= 16'd0; adj_reg_1 <= 16'd0; adj_reg_2 <= 16'd0; adj_reg_3 <= 16'd0;
            adj_reg_4 <= 16'd0; adj_reg_5 <= 16'd0; adj_reg_6 <= 16'd0; adj_reg_7 <= 16'd0;
            adj_reg_8 <= 16'd0; adj_reg_9 <= 16'd0; adj_reg_10 <= 16'd0; adj_reg_11 <= 16'd0;
            adj_reg_12 <= 16'd0; adj_reg_13 <= 16'd0; adj_reg_14 <= 16'd0; adj_reg_15 <= 16'd0;
            
            temp_match_0 <= 4'd0; temp_match_1 <= 4'd0; temp_match_2 <= 4'd0; temp_match_3 <= 4'd0;
            temp_match_4 <= 4'd0; temp_match_5 <= 4'd0; temp_match_6 <= 4'd0; temp_match_7 <= 4'd0;
            temp_match_8 <= 4'd0; temp_match_9 <= 4'd0; temp_match_10 <= 4'd0; temp_match_11 <= 4'd0;
            temp_match_12 <= 4'd0; temp_match_13 <= 4'd0; temp_match_14 <= 4'd0; temp_match_15 <= 4'd0;
            
            btn_match_0 <= 4'd15; btn_match_1 <= 4'd15; btn_match_2 <= 4'd15; btn_match_3 <= 4'd15;
            btn_match_4 <= 4'd15; btn_match_5 <= 4'd15; btn_match_6 <= 4'd15; btn_match_7 <= 4'd15;
            btn_match_8 <= 4'd15; btn_match_9 <= 4'd15; btn_match_10 <= 4'd15; btn_match_11 <= 4'd15;
            btn_match_12 <= 4'd15; btn_match_13 <= 4'd15; btn_match_14 <= 4'd15; btn_match_15 <= 4'd15;
            
            matched_0 <= 1'b0; matched_1 <= 1'b0; matched_2 <= 1'b0; matched_3 <= 1'b0;
            matched_4 <= 1'b0; matched_5 <= 1'b0; matched_6 <= 1'b0; matched_7 <= 1'b0;
            matched_8 <= 1'b0; matched_9 <= 1'b0; matched_10 <= 1'b0; matched_11 <= 1'b0;
            matched_12 <= 1'b0; matched_13 <= 1'b0; matched_14 <= 1'b0; matched_15 <= 1'b0;
            
            matching_0_0 <= 4'd0; matching_0_1 <= 4'd0; matching_0_2 <= 4'd0; matching_0_3 <= 4'd0;
            matching_0_4 <= 4'd0; matching_0_5 <= 4'd0; matching_0_6 <= 4'd0; matching_0_7 <= 4'd0;
            matching_0_8 <= 4'd0; matching_0_9 <= 4'd0; matching_0_10 <= 4'd0; matching_0_11 <= 4'd0;
            matching_0_12 <= 4'd0; matching_0_13 <= 4'd0; matching_0_14 <= 4'd0; matching_0_15 <= 4'd0;
            matching_1_0 <= 4'd0; matching_1_1 <= 4'd0; matching_1_2 <= 4'd0; matching_1_3 <= 4'd0;
            matching_1_4 <= 4'd0; matching_1_5 <= 4'd0; matching_1_6 <= 4'd0; matching_1_7 <= 4'd0;
            matching_1_8 <= 4'd0; matching_1_9 <= 4'd0; matching_1_10 <= 4'd0; matching_1_11 <= 4'd0;
            matching_1_12 <= 4'd0; matching_1_13 <= 4'd0; matching_1_14 <= 4'd0; matching_1_15 <= 4'd0;
            matching_2_0 <= 4'd0; matching_2_1 <= 4'd0; matching_2_2 <= 4'd0; matching_2_3 <= 4'd0;
            matching_2_4 <= 4'd0; matching_2_5 <= 4'd0; matching_2_6 <= 4'd0; matching_2_7 <= 4'd0;
            matching_2_8 <= 4'd0; matching_2_9 <= 4'd0; matching_2_10 <= 4'd0; matching_2_11 <= 4'd0;
            matching_2_12 <= 4'd0; matching_2_13 <= 4'd0; matching_2_14 <= 4'd0; matching_2_15 <= 4'd0;
            matching_3_0 <= 4'd0; matching_3_1 <= 4'd0; matching_3_2 <= 4'd0; matching_3_3 <= 4'd0;
            matching_3_4 <= 4'd0; matching_3_5 <= 4'd0; matching_3_6 <= 4'd0; matching_3_7 <= 4'd0;
            matching_3_8 <= 4'd0; matching_3_9 <= 4'd0; matching_3_10 <= 4'd0; matching_3_11 <= 4'd0;
            matching_3_12 <= 4'd0; matching_3_13 <= 4'd0; matching_3_14 <= 4'd0; matching_3_15 <= 4'd0;
            matching_4_0 <= 4'd0; matching_4_1 <= 4'd0; matching_4_2 <= 4'd0; matching_4_3 <= 4'd0;
            matching_4_4 <= 4'd0; matching_4_5 <= 4'd0; matching_4_6 <= 4'd0; matching_4_7 <= 4'd0;
            matching_4_8 <= 4'd0; matching_4_9 <= 4'd0; matching_4_10 <= 4'd0; matching_4_11 <= 4'd0;
            matching_4_12 <= 4'd0; matching_4_13 <= 4'd0; matching_4_14 <= 4'd0; matching_4_15 <= 4'd0;
            matching_5_0 <= 4'd0; matching_5_1 <= 4'd0; matching_5_2 <= 4'd0; matching_5_3 <= 4'd0;
            matching_5_4 <= 4'd0; matching_5_5 <= 4'd0; matching_5_6 <= 4'd0; matching_5_7 <= 4'd0;
            matching_5_8 <= 4'd0; matching_5_9 <= 4'd0; matching_5_10 <= 4'd0; matching_5_11 <= 4'd0;
            matching_5_12 <= 4'd0; matching_5_13 <= 4'd0; matching_5_14 <= 4'd0; matching_5_15 <= 4'd0;
            matching_6_0 <= 4'd0; matching_6_1 <= 4'd0; matching_6_2 <= 4'd0; matching_6_3 <= 4'd0;
            matching_6_4 <= 4'd0; matching_6_5 <= 4'd0; matching_6_6 <= 4'd0; matching_6_7 <= 4'd0;
            matching_6_8 <= 4'd0; matching_6_9 <= 4'd0; matching_6_10 <= 4'd0; matching_6_11 <= 4'd0;
            matching_6_12 <= 4'd0; matching_6_13 <= 4'd0; matching_6_14 <= 4'd0; matching_6_15 <= 4'd0;
            matching_7_0 <= 4'd0; matching_7_1 <= 4'd0; matching_7_2 <= 4'd0; matching_7_3 <= 4'd0;
            matching_7_4 <= 4'd0; matching_7_5 <= 4'd0; matching_7_6 <= 4'd0; matching_7_7 <= 4'd0;
            matching_7_8 <= 4'd0; matching_7_9 <= 4'd0; matching_7_10 <= 4'd0; matching_7_11 <= 4'd0;
            matching_7_12 <= 4'd0; matching_7_13 <= 4'd0; matching_7_14 <= 4'd0; matching_7_15 <= 4'd0;
            matching_8_0 <= 4'd0; matching_8_1 <= 4'd0; matching_8_2 <= 4'd0; matching_8_3 <= 4'd0;
            matching_8_4 <= 4'd0; matching_8_5 <= 4'd0; matching_8_6 <= 4'd0; matching_8_7 <= 4'd0;
            matching_8_8 <= 4'd0; matching_8_9 <= 4'd0; matching_8_10 <= 4'd0; matching_8_11 <= 4'd0;
            matching_8_12 <= 4'd0; matching_8_13 <= 4'd0; matching_8_14 <= 4'd0; matching_8_15 <= 4'd0;
            matching_9_0 <= 4'd0; matching_9_1 <= 4'd0; matching_9_2 <= 4'd0; matching_9_3 <= 4'd0;
            matching_9_4 <= 4'd0; matching_9_5 <= 4'd0; matching_9_6 <= 4'd0; matching_9_7 <= 4'd0;
            matching_9_8 <= 4'd0; matching_9_9 <= 4'd0; matching_9_10 <= 4'd0; matching_9_11 <= 4'd0;
            matching_9_12 <= 4'd0; matching_9_13 <= 4'd0; matching_9_14 <= 4'd0; matching_9_15 <= 4'd0;
            matching_10_0 <= 4'd0; matching_10_1 <= 4'd0; matching_10_2 <= 4'd0; matching_10_3 <= 4'd0;
            matching_10_4 <= 4'd0; matching_10_5 <= 4'd0; matching_10_6 <= 4'd0; matching_10_7 <= 4'd0;
            matching_10_8 <= 4'd0; matching_10_9 <= 4'd0; matching_10_10 <= 4'd0; matching_10_11 <= 4'd0;
            matching_10_12 <= 4'd0; matching_10_13 <= 4'd0; matching_10_14 <= 4'd0; matching_10_15 <= 4'd0;
            matching_11_0 <= 4'd0; matching_11_1 <= 4'd0; matching_11_2 <= 4'd0; matching_11_3 <= 4'd0;
            matching_11_4 <= 4'd0; matching_11_5 <= 4'd0; matching_11_6 <= 4'd0; matching_11_7 <= 4'd0;
            matching_11_8 <= 4'd0; matching_11_9 <= 4'd0; matching_11_10 <= 4'd0; matching_11_11 <= 4'd0;
            matching_11_12 <= 4'd0; matching_11_13 <= 4'd0; matching_11_14 <= 4'd0; matching_11_15 <= 4'd0;
            matching_12_0 <= 4'd0; matching_12_1 <= 4'd0; matching_12_2 <= 4'd0; matching_12_3 <= 4'd0;
            matching_12_4 <= 4'd0; matching_12_5 <= 4'd0; matching_12_6 <= 4'd0; matching_12_7 <= 4'd0;
            matching_12_8 <= 4'd0; matching_12_9 <= 4'd0; matching_12_10 <= 4'd0; matching_12_11 <= 4'd0;
            matching_12_12 <= 4'd0; matching_12_13 <= 4'd0; matching_12_14 <= 4'd0; matching_12_15 <= 4'd0;
            matching_13_0 <= 4'd0; matching_13_1 <= 4'd0; matching_13_2 <= 4'd0; matching_13_3 <= 4'd0;
            matching_13_4 <= 4'd0; matching_13_5 <= 4'd0; matching_13_6 <= 4'd0; matching_13_7 <= 4'd0;
            matching_13_8 <= 4'd0; matching_13_9 <= 4'd0; matching_13_10 <= 4'd0; matching_13_11 <= 4'd0;
            matching_13_12 <= 4'd0; matching_13_13 <= 4'd0; matching_13_14 <= 4'd0; matching_13_15 <= 4'd0;
            matching_14_0 <= 4'd0; matching_14_1 <= 4'd0; matching_14_2 <= 4'd0; matching_14_3 <= 4'd0;
            matching_14_4 <= 4'd0; matching_14_5 <= 4'd0; matching_14_6 <= 4'd0; matching_14_7 <= 4'd0;
            matching_14_8 <= 4'd0; matching_14_9 <= 4'd0; matching_14_10 <= 4'd0; matching_14_11 <= 4'd0;
            matching_14_12 <= 4'd0; matching_14_13 <= 4'd0; matching_14_14 <= 4'd0; matching_14_15 <= 4'd0;
            matching_15_0 <= 4'd0; matching_15_1 <= 4'd0; matching_15_2 <= 4'd0; matching_15_3 <= 4'd0;
            matching_15_4 <= 4'd0; matching_15_5 <= 4'd0; matching_15_6 <= 4'd0; matching_15_7 <= 4'd0;
            matching_15_8 <= 4'd0; matching_15_9 <= 4'd0; matching_15_10 <= 4'd0; matching_15_11 <= 4'd0;
            matching_15_12 <= 4'd0; matching_15_13 <= 4'd0; matching_15_14 <= 4'd0; matching_15_15 <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= STORE_INPUT;
                        cycle_count <= 32'd0;
                        k <= 4'd0;
                        current_matching_idx <= 4'd0;
                        n_stored <= 1'b0;
                    end
                end
                
                STORE_INPUT: begin
                    if (!n_stored) begin
                        adj_reg_0 <= {adj_0_15, adj_0_14, adj_0_13, adj_0_12, adj_0_11, adj_0_10, adj_0_9, adj_0_8, adj_0_7, adj_0_6, adj_0_5, adj_0_4, adj_0_3, adj_0_2, adj_0_1, adj_0_0};
                        adj_reg_1 <= {adj_1_15, adj_1_14, adj_1_13, adj_1_12, adj_1_11, adj_1_10, adj_1_9, adj_1_8, adj_1_7, adj_1_6, adj_1_5, adj_1_4, adj_1_3, adj_1_2, adj_1_1, adj_1_0};
                        adj_reg_2 <= {adj_2_15, adj_2_14, adj_2_13, adj_2_12, adj_2_11, adj_2_10, adj_2_9, adj_2_8, adj_2_7, adj_2_6, adj_2_5, adj_2_4, adj_2_3, adj_2_2, adj_2_1, adj_2_0};
                        adj_reg_3 <= {adj_3_15, adj_3_14, adj_3_13, adj_3_12, adj_3_11, adj_3_10, adj_3_9, adj_3_8, adj_3_7, adj_3_6, adj_3_5, adj_3_4, adj_3_3, adj_3_2, adj_3_1, adj_3_0};
                        adj_reg_4 <= {adj_4_15, adj_4_14, adj_4_13, adj_4_12, adj_4_11, adj_4_10, adj_4_9, adj_4_8, adj_4_7, adj_4_6, adj_4_5, adj_4_4, adj_4_3, adj_4_2, adj_4_1, adj_4_0};
                        adj_reg_5 <= {adj_5_15, adj_5_14, adj_5_13, adj_5_12, adj_5_11, adj_5_10, adj_5_9, adj_5_8, adj_5_7, adj_5_6, adj_5_5, adj_5_4, adj_5_3, adj_5_2, adj_5_1, adj_5_0};
                        adj_reg_6 <= {adj_6_15, adj_6_14, adj_6_13, adj_6_12, adj_6_11, adj_6_10, adj_6_9, adj_6_8, adj_6_7, adj_6_6, adj_6_5, adj_6_4, adj_6_3, adj_6_2, adj_6_1, adj_6_0};
                        adj_reg_7 <= {adj_7_15, adj_7_14, adj_7_13, adj_7_12, adj_7_11, adj_7_10, adj_7_9, adj_7_8, adj_7_7, adj_7_6, adj_7_5, adj_7_4, adj_7_3, adj_7_2, adj_7_1, adj_7_0};
                        adj_reg_8 <= {adj_8_15, adj_8_14, adj_8_13, adj_8_12, adj_8_11, adj_8_10, adj_8_9, adj_8_8, adj_8_7, adj_8_6, adj_8_5, adj_8_4, adj_8_3, adj_8_2, adj_8_1, adj_8_0};
                        adj_reg_9 <= {adj_9_15, adj_9_14, adj_9_13, adj_9_12, adj_9_11, adj_9_10, adj_9_9, adj_9_8, adj_9_7, adj_9_6, adj_9_5, adj_9_4, adj_9_3, adj_9_2, adj_9_1, adj_9_0};
                        adj_reg_10 <= {adj_10_15, adj_10_14, adj_10_13, adj_10_12, adj_10_11, adj_10_10, adj_10_9, adj_10_8, adj_10_7, adj_10_6, adj_10_5, adj_10_4, adj_10_3, adj_10_2, adj_10_1, adj_10_0};
                        adj_reg_11 <= {adj_11_15, adj_11_14, adj_11_13, adj_11_12, adj_11_11, adj_11_10, adj_11_9, adj_11_8, adj_11_7, adj_11_6, adj_11_5, adj_11_4, adj_11_3, adj_11_2, adj_11_1, adj_11_0};
                        adj_reg_12 <= {adj_12_15, adj_12_14, adj_12_13, adj_12_12, adj_12_11, adj_12_10, adj_12_9, adj_12_8, adj_12_7, adj_12_6, adj_12_5, adj_12_4, adj_12_3, adj_12_2, adj_12_1, adj_12_0};
                        adj_reg_13 <= {adj_13_15, adj_13_14, adj_13_13, adj_13_12, adj_13_11, adj_13_10, adj_13_9, adj_13_8, adj_13_7, adj_13_6, adj_13_5, adj_13_4, adj_13_3, adj_13_2, adj_13_1, adj_13_0};
                        adj_reg_14 <= {adj_14_15, adj_14_14, adj_14_13, adj_14_12, adj_14_11, adj_14_10, adj_14_9, adj_14_8, adj_14_7, adj_14_6, adj_14_5, adj_14_4, adj_14_3, adj_14_2, adj_14_1, adj_14_0};
                        adj_reg_15 <= {adj_15_15, adj_15_14, adj_15_13, adj_15_12, adj_15_11, adj_15_10, adj_15_9, adj_15_8, adj_15_7, adj_15_6, adj_15_5, adj_15_4, adj_15_3, adj_15_2, adj_15_1, adj_15_0};
                        n_stored <= 1'b1;
                        current_person <= 4'd0;
                    end else begin
                        state <= COMPUTE_MATCHING;
                        current_person <= 4'd0;
                        current_button <= 4'd0;
                        matching_size <= 4'd0;
                        temp_matching_valid <= 1'b0;
                        matched_0 <= 1'b0; matched_1 <= 1'b0; matched_2 <= 1'b0; matched_3 <= 1'b0;
                        matched_4 <= 1'b0; matched_5 <= 1'b0; matched_6 <= 1'b0; matched_7 <= 1'b0;
                        matched_8 <= 1'b0; matched_9 <= 1'b0; matched_10 <= 1'b0; matched_11 <= 1'b0;
                        matched_12 <= 1'b0; matched_13 <= 1'b0; matched_14 <= 1'b0; matched_15 <= 1'b0;
                    end
                end
                
                COMPUTE_MATCHING: begin
                    cycle_count <= cycle_count + 32'd1;
                    
                    // Greedy bipartite matching for current_person
                    if (current_person < n) begin
                        // Check if current person is already matched
                        if (!matched_0 && !matched_1 && !matched_2 && !matched_3 &&
                            !matched_4 && !matched_5 && !matched_6 && !matched_7 &&
                            !matched_8 && !matched_9 && !matched_10 && !matched_11 &&
                            !matched_12 && !matched_13 && !matched_14 && !matched_15) begin
                            
                            // Try to find an unmatched button
                            if (current_button < n) begin
                                // Check if edge exists
                                if ((current_person == 4'd0 && adj_reg_0[current_button]) ||
                                    (current_person == 4'd1 && adj_reg_1[current_button]) ||
                                    (current_person == 4'd2 && adj_reg_2[current_button]) ||
                                    (current_person == 4'd3 && adj_reg_3[current_button]) ||
                                    (current_person == 4'd4 && adj_reg_4[current_button]) ||
                                    (current_person == 4'd5 && adj_reg_5[current_button]) ||
                                    (current_person == 4'd6 && adj_reg_6[current_button]) ||
                                    (current_person == 4'd7 && adj_reg_7[current_button]) ||
                                    (current_person == 4'd8 && adj_reg_8[current_button]) ||
                                    (current_person == 4'd9 && adj_reg_9[current_button]) ||
                                    (current_person == 4'd10 && adj_reg_10[current_button]) ||
                                    (current_person == 4'd11 && adj_reg_11[current_button]) ||
                                    (current_person == 4'd12 && adj_reg_12[current_button]) ||
                                    (current_person == 4'd13 && adj_reg_13[current_button]) ||
                                    (current_person == 4'd14 && adj_reg_14[current_button]) ||
                                    (current_person == 4'd15 && adj_reg_15[current_button])) begin
                                    
                                    // Check if this button is already matched
                                    if ((current_button == 4'd0 && btn_match_0 >= n) ||
                                        (current_button == 4'd1 && btn_match_1 >= n) ||
                                        (current_button == 4'd2 && btn_match_2 >= n) ||
                                        (current_button == 4'd3 && btn_match_3 >= n) ||
                                        (current_button == 4'd4 && btn_match_4 >= n) ||
                                        (current_button == 4'd5 && btn_match_5 >= n) ||
                                        (current_button == 4'd6 && btn_match_6 >= n) ||
                                        (current_button == 4'd7 && btn_match_7 >= n) ||
                                        (current_button == 4'd8 && btn_match_8 >= n) ||
                                        (current_button == 4'd9 && btn_match_9 >= n) ||
                                        (current_button == 4'd10 && btn_match_10 >= n) ||
                                        (current_button == 4'd11 && btn_match_11 >= n) ||
                                        (current_button == 4'd12 && btn_match_12 >= n) ||
                                        (current_button == 4'd13 && btn_match_13 >= n) ||
                                        (current_button == 4'd14 && btn_match_14 >= n) ||
                                        (current_button == 4'd15 && btn_match_15 >= n)) begin
                                        
                                        // Match found
                                        case (current_button)
                                            4'd0: begin btn_match_0 <= current_person; matched_0 <= 1'b1; end
                                            4'd1: begin btn_match_1 <= current_person; matched_1 <= 1'b1; end
                                            4'd2: begin btn_match_2 <= current_person; matched_2 <= 1'b1; end
                                            4'd3: begin btn_match_3 <= current_person; matched_3 <= 1'b1; end
                                            4'd4: begin btn_match_4 <= current_person; matched_4 <= 1'b1; end
                                            4'd5: begin btn_match_5 <= current_person; matched_5 <= 1'b1; end
                                            4'd6: begin btn_match_6 <= current_person; matched_6 <= 1'b1; end
                                            4'd7: begin btn_match_7 <= current_person; matched_7 <= 1'b1; end
                                            4'd8: begin btn_match_8 <= current_person; matched_8 <= 1'b1; end
                                            4'd9: begin btn_match_9 <= current_person; matched_9 <= 1'b1; end
                                            4'd10: begin btn_match_10 <= current_person; matched_10 <= 1'b1; end
                                            4'd11: begin btn_match_11 <= current_person; matched_11 <= 1'b1; end
                                            4'd12: begin btn_match_12 <= current_person; matched_12 <= 1'b1; end
                                            4'd13: begin btn_match_13 <= current_person; matched_13 <= 1'b1; end
                                            4'd14: begin btn_match_14 <= current_person; matched_14 <= 1'b1; end
                                            4'd15: begin btn_match_15 <= current_person; matched_15 <= 1'b1; end
                                        endcase
                                        matching_size <= matching_size + 4'd1;
                                        current_person <= current_person + 4'd1;
                                        current_button <= 4'd0;
                                    end else begin
                                        current_button <= current_button + 4'd1;
                                    end
                                end else begin
                                    current_button <= current_button + 4'd1;
                                end
                            end else begin
                                current_person <= current_person + 4'd1;
                                current_button <= 4'd0;
                            end
                        end else begin
                            current_person <= current_person + 4'd1;
                            current_button <= 4'd0;
                        end
                    end else begin
                        // All persons processed
                        state <= CHECK_MATCH;
                    end
                end
                
                CHECK_MATCH: begin
                    // Check if matching size equals n
                    if (matching_size == n) begin
                        // Valid perfect matching
                        temp_matching_valid <= 1'b1;
                        state <= STORE_MATCHING;
                    end else begin
                        // No more perfect matchings
                        temp_matching_valid <= 1'b0;
                        if (current_matching_idx == 4'd0) begin
                            // No matchings found at all
                            done <= 1'b1;
                            state <= DONE_STATE;
                        end else begin
                            done <= 1'b1;
                            state <= DONE_STATE;
                        end
                    end
                end
                
                STORE_MATCHING: begin
                    if (temp_matching_valid) begin
                        // Store the matching based on current_matching_idx
                        case (current_matching_idx)
                            4'd0: begin
                                matching_0_0 <= btn_match_0; matching_0_1 <= btn_match_1; matching_0_2 <= btn_match_2; matching_0_3 <= btn_match_3;
                                matching_0_4 <= btn_match_4; matching_0_5 <= btn_match_5; matching_0_6 <= btn_match_6; matching_0_7 <= btn_match_7;
                                matching_0_8 <= btn_match_8; matching_0_9 <= btn_match_9; matching_0_10 <= btn_match_10; matching_0_11 <= btn_match_11;
                                matching_0_12 <= btn_match_12; matching_0_13 <= btn_match_13; matching_0_14 <= btn_match_14; matching_0_15 <= btn_match_15;
                            end
                            4'd1: begin
                                matching_1_0 <= btn_match_0; matching_1_1 <= btn_match_1; matching_1_2 <= btn_match_2; matching_1_3 <= btn_match_3;
                                matching_1_4 <= btn_match_4; matching_1_5 <= btn_match_5; matching_1_6 <= btn_match_6; matching_1_7 <= btn_match_7;
                                matching_1_8 <= btn_match_8; matching_1_9 <= btn_match_9; matching_1_10 <= btn_match_10; matching_1_11 <= btn_match_11;
                                matching_1_12 <= btn_match_12; matching_1_13 <= btn_match_13; matching_1_14 <= btn_match_14; matching_1_15 <= btn_match_15;
                            end
                            4'd2: begin
                                matching_2_0 <= btn_match_0; matching_2_1 <= btn_match_1; matching_2_2 <= btn_match_2; matching_2_3 <= btn_match_3;
                                matching_2_4 <= btn_match_4; matching_2_5 <= btn_match_5; matching_2_6 <= btn_match_6; matching_2_7 <= btn_match_7;
                                matching_2_8 <= btn_match_8; matching_2_9 <= btn_match_9; matching_2_10 <= btn_match_10; matching_2_11 <= btn_match_11;
                                matching_2_12 <= btn_match_12; matching_2_13 <= btn_match_13; matching_2_14 <= btn_match_14; matching_2_15 <= btn_match_15;
                            end
                            4'd3: begin
                                matching_3_0 <= btn_match_0; matching_3_1 <= btn_match_1; matching_3_2 <= btn_match_2; matching_3_3 <= btn_match_3;
                                matching_3_4 <= btn_match_4; matching_3_5 <= btn_match_5; matching_3_6 <= btn_match_6; matching_3_7 <= btn_match_7;
                                matching_3_8 <= btn_match_8; matching_3_9 <= btn_match_9; matching_3_10 <= btn_match_10; matching_3_11 <= btn_match_11;
                                matching_3_12 <= btn_match_12; matching_3_13 <= btn_match_13; matching_3_14 <= btn_match_14; matching_3_15 <= btn_match_15;
                            end
                            4'd4: begin
                                matching_4_0 <= btn_match_0; matching_4_1 <= btn_match_1; matching_4_2 <= btn_match_2; matching_4_3 <= btn_match_3;
                                matching_4_4 <= btn_match_4; matching_4_5 <= btn_match_5; matching_4_6 <= btn_match_6; matching_4_7 <= btn_match_7;
                                matching_4_8 <= btn_match_8; matching_4_9 <= btn_match_9; matching_4_10 <= btn_match_10; matching_4_11 <= btn_match_11;
                                matching_4_12 <= btn_match_12; matching_4_13 <= btn_match_13; matching_4_14 <= btn_match_14; matching_4_15 <= btn_match_15;
                            end
                            4'd5: begin
                                matching_5_0 <= btn_match_0; matching_5_1 <= btn_match_1; matching_5_2 <= btn_match_2; matching_5_3 <= btn_match_3;
                                matching_5_4 <= btn_match_4; matching_5_5 <= btn_match_5; matching_5_6 <= btn_match_6; matching_5_7 <= btn_match_7;
                                matching_5_8 <= btn_match_8; matching_5_9 <= btn_match_9; matching_5_10 <= btn_match_10; matching_5_11 <= btn_match_11;
                                matching_5_12 <= btn_match_12; matching_5_13 <= btn_match_13; matching_5_14 <= btn_match_14; matching_5_15 <= btn_match_15;
                            end
                            4'd6: begin
                                matching_6_0 <= btn_match_0; matching_6_1 <= btn_match_1; matching_6_2 <= btn_match_2; matching_6_3 <= btn_match_3;
                                matching_6_4 <= btn_match_4; matching_6_5 <= btn_match_5; matching_6_6 <= btn_match_6; matching_6_7 <= btn_match_7;
                                matching_6_8 <= btn_match_8; matching_6_9 <= btn_match_9; matching_6_10 <= btn_match_10; matching_6_11 <= btn_match_11;
                                matching_6_12 <= btn_match_12; matching_6_13 <= btn_match_13; matching_6_14 <= btn_match_14; matching_6_15 <= btn_match_15;
                            end
                            4'd7: begin
                                matching_7_0 <= btn_match_0; matching_7_1 <= btn_match_1; matching_7_2 <= btn_match_2; matching_7_3 <= btn_match_3;
                                matching_7_4 <= btn_match_4; matching_7_5 <= btn_match_5; matching_7_6 <= btn_match_6; matching_7_7 <= btn_match_7;
                                matching_7_8 <= btn_match_8; matching_7_9 <= btn_match_9; matching_7_10 <= btn_match_10; matching_7_11 <= btn_match_11;
                                matching_7_12 <= btn_match_12; matching_7_13 <= btn_match_13; matching_7_14 <= btn_match_14; matching_7_15 <= btn_match_15;
                            end
                            4'd8: begin
                                matching_8_0 <= btn_match_0; matching_8_1 <= btn_match_1; matching_8_2 <= btn_match_2; matching_8_3 <= btn_match_3;
                                matching_8_4 <= btn_match_4; matching_8_5 <= btn_match_5; matching_8_6 <= btn_match_6; matching_8_7 <= btn_match_7;
                                matching_8_8 <= btn_match_8; matching_8_9 <= btn_match_9; matching_8_10 <= btn_match_10; matching_8_11 <= btn_match_11;
                                matching_8_12 <= btn_match_12; matching_8_13 <= btn_match_13; matching_8_14 <= btn_match_14; matching_8_15 <= btn_match_15;
                            end
                            4'd9: begin
                                matching_9_0 <= btn_match_0; matching_9_1 <= btn_match_1; matching_9_2 <= btn_match_2; matching_9_3 <= btn_match_3;
                                matching_9_4 <= btn_match_4; matching_9_5 <= btn_match_5; matching_9_6 <= btn_match_6; matching_9_7 <= btn_match_7;
                                matching_9_8 <= btn_match_8; matching_9_9 <= btn_match_9; matching_9_10 <= btn_match_10; matching_9_11 <= btn_match_11;
                                matching_9_12 <= btn_match_12; matching_9_13 <= btn_match_13; matching_9_14 <= btn_match_14; matching_9_15 <= btn_match_15;
                            end
                            4'd10: begin
                                matching_10_0 <= btn_match_0; matching_10_1 <= btn_match_1; matching_10_2 <= btn_match_2; matching_10_3 <= btn_match_3;
                                matching_10_4 <= btn_match_4; matching_10_5 <= btn_match_5; matching_10_6 <= btn_match_6; matching_10_7 <= btn_match_7;
                                matching_10_8 <= btn_match_8; matching_10_9 <= btn_match_9; matching_10_10 <= btn_match_10; matching_10_11 <= btn_match_11;
                                matching_10_12 <= btn_match_12; matching_10_13 <= btn_match_13; matching_10_14 <= btn_match_14; matching_10_15 <= btn_match_15;
                            end
                            4'd11: begin
                                matching_11_0 <= btn_match_0; matching_11_1 <= btn_match_1; matching_11_2 <= btn_match_2; matching_11_3 <= btn_match_3;
                                matching_11_4 <= btn_match_4; matching_11_5 <= btn_match_5; matching_11_6 <= btn_match_6; matching_11_7 <= btn_match_7;
                                matching_11_8 <= btn_match_8; matching_11_9 <= btn_match_9; matching_11_10 <= btn_match_10; matching_11_11 <= btn_match_11;
                                matching_11_12 <= btn_match_12; matching_11_13 <= btn_match_13; matching_11_14 <= btn_match_14; matching_11_15 <= btn_match_15;
                            end
                            4'd12: begin
                                matching_12_0 <= btn_match_0; matching_12_1 <= btn_match_1; matching_12_2 <= btn_match_2; matching_12_3 <= btn_match_3;
                                matching_12_4 <= btn_match_4; matching_12_5 <= btn_match_5; matching_12_6 <= btn_match_6; matching_12_7 <= btn_match_7;
                                matching_12_8 <= btn_match_8; matching_12_9 <= btn_match_9; matching_12_10 <= btn_match_10; matching_12_11 <= btn_match_11;
                                matching_12_12 <= btn_match_12; matching_12_13 <= btn_match_13; matching_12_14 <= btn_match_14; matching_12_15 <= btn_match_15;
                            end
                            4'd13: begin
                                matching_13_0 <= btn_match_0; matching_13_1 <= btn_match_1; matching_13_2 <= btn_match_2; matching_13_3 <= btn_match_3;
                                matching_13_4 <= btn_match_4; matching_13_5 <= btn_match_5; matching_13_6 <= btn_match_6; matching_13_7 <= btn_match_7;
                                matching_13_8 <= btn_match_8; matching_13_9 <= btn_match_9; matching_13_10 <= btn_match_10; matching_13_11 <= btn_match_11;
                                matching_13_12 <= btn_match_12; matching_13_13 <= btn_match_13; matching_13_14 <= btn_match_14; matching_13_15 <= btn_match_15;
                            end
                            4'd14: begin
                                matching_14_0 <= btn_match_0; matching_14_1 <= btn_match_1; matching_14_2 <= btn_match_2; matching_14_3 <= btn_match_3;
                                matching_14_4 <= btn_match_4; matching_14_5 <= btn_match_5; matching_14_6 <= btn_match_6; matching_14_7 <= btn_match_7;
                                matching_14_8 <= btn_match_8; matching_14_9 <= btn_match_9; matching_14_10 <= btn_match_10; matching_14_11 <= btn_match_11;
                                matching_14_12 <= btn_match_12; matching_14_13 <= btn_match_13; matching_14_14 <= btn_match_14; matching_14_15 <= btn_match_15;
                            end
                            4'd15: begin
                                matching_15_0 <= btn_match_0; matching_15_1 <= btn_match_1; matching_15_2 <= btn_match_2; matching_15_3 <= btn_match_3;
                                matching_15_4 <= btn_match_4; matching_15_5 <= btn_match_5; matching_15_6 <= btn_match_6; matching_15_7 <= btn_match_7;
                                matching_15_8 <= btn_match_8; matching_15_9 <= btn_match_9; matching_15_10 <= btn_match_10; matching_15_11 <= btn_match_11;
                                matching_15_12 <= btn_match_12; matching_15_13 <= btn_match_13; matching_15_14 <= btn_match_14; matching_15_15 <= btn_match_15;
                            end
                        endcase
                        k <= k + 4'd1;
                        state <= REMOVE_EDGES;
                    end
                end
                
                REMOVE_EDGES: begin
                    // Remove all matched edges from adj_matrix
                    for (i = 0; i < 16; i = i + 1) begin
                        for (j = 0; j < 16; j = j + 1) begin
                            if (i < n && j < n) begin
                                // Check if this edge was used in the matching
                                if ((i == 4'd0 && btn_match_0 == j) ||
                                    (i == 4'd1 && btn_match_1 == j) ||
                                    (i == 4'd2 && btn_match_2 == j) ||
                                    (i == 4'd3 && btn_match_3 == j) ||
                                    (i == 4'd4 && btn_match_4 == j) ||
                                    (i == 4'd5 && btn_match_5 == j) ||
                                    (i == 4'd6 && btn_match_6 == j) ||
                                    (i == 4'd7 && btn_match_7 == j) ||
                                    (i == 4'd8 && btn_match_8 == j) ||
                                    (i == 4'd9 && btn_match_9 == j) ||
                                    (i == 4'd10 && btn_match_10 == j) ||
                                    (i == 4'd11 && btn_match_11 == j) ||
                                    (i == 4'd12 && btn_match_12 == j) ||
                                    (i == 4'd13 && btn_match_13 == j) ||
                                    (i == 4'd14 && btn_match_14 == j) ||
                                    (i == 4'd15 && btn_match_15 == j)) begin
                                    
                                    // Clear the bit in the appropriate register
                                    if (i == 4'd0) adj_reg_0[j] <= 1'b0;
                                    if (i == 4'd1) adj_reg_1[j] <= 1'b0;
                                    if (i == 4'd2) adj_reg_2[j] <= 1'b0;
                                    if (i == 4'd3) adj_reg_3[j] <= 1'b0;
                                    if (i == 4'd4) adj_reg_4[j] <= 1'b0;
                                    if (i == 4'd5) adj_reg_5[j] <= 1'b0;
                                    if (i == 4'd6) adj_reg_6[j] <= 1'b0;
                                    if (i == 4'd7) adj_reg_7[j] <= 1'b0;
                                    if (i == 4'd8) adj_reg_8[j] <= 1'b0;
                                    if (i == 4'd9) adj_reg_9[j] <= 1'b0;
                                    if (i == 4'd10) adj_reg_10[j] <= 1'b0;
                                    if (i == 4'd11) adj_reg_11[j] <= 1'b0;
                                    if (i == 4'd12) adj_reg_12[j] <= 1'b0;
                                    if (i == 4'd13) adj_reg_13[j] <= 1'b0;
                                    if (i == 4'd14) adj_reg_14[j] <= 1'b0;
                                    if (i == 4'd15) adj_reg_15[j] <= 1'b0;
                                end
                            end
                        end
                    end
                    
                    // Reset for next iteration
                    current_matching_idx <= current_matching_idx + 4'd1;
                    current_person <= 4'd0;
                    current_button <= 4'd0;
                    
                    if (current_matching_idx < 4'd15) begin
                        // Check timeout
                        if (cycle_count >= MAX_CYCLES) begin
                            done <= 1'b1;
                            state <= DONE_STATE;
                        end else begin
                            state <= STORE_INPUT;
                            n_stored <= 1'b0;
                        end
                    end else begin
                        // Too many matchings, stop
                        done <= 1'b1;
                        state <= DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    // Done is already asserted, wait for reset
                    done <= 1'b0;  // Pulse done for 1 cycle
                    if (!start) begin
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule