module bipartite_matching(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire adj_0_0, input wire adj_0_1, input wire adj_0_2, input wire adj_0_3, input wire adj_0_4, input wire adj_0_5, input wire adj_0_6, input wire adj_0_7,
    input wire adj_0_8, input wire adj_0_9, input wire adj_0_10, input wire adj_0_11, input wire adj_0_12, input wire adj_0_13, input wire adj_0_14, input wire adj_0_15,
    input wire adj_1_0, input wire adj_1_1, input wire adj_1_2, input wire adj_1_3, input wire adj_1_4, input wire adj_1_5, input wire adj_1_6, input wire adj_1_7,
    input wire adj_1_8, input wire adj_1_9, input wire adj_1_10, input wire adj_1_11, input wire adj_1_12, input wire adj_1_13, input wire adj_1_14, input wire adj_1_15,
    input wire adj_2_0, input wire adj_2_1, input wire adj_2_2, input wire adj_2_3, input wire adj_2_4, input wire adj_2_5, input wire adj_2_6, input wire adj_2_7,
    input wire adj_2_8, input wire adj_2_9, input wire adj_2_10, input wire adj_2_11, input wire adj_2_12, input wire adj_2_13, input wire adj_2_14, input wire adj_2_15,
    input wire adj_3_0, input wire adj_3_1, input wire adj_3_2, input wire adj_3_3, input wire adj_3_4, input wire adj_3_5, input wire adj_3_6, input wire adj_3_7,
    input wire adj_3_8, input wire adj_3_9, input wire adj_3_10, input wire adj_3_11, input wire adj_3_12, input wire adj_3_13, input wire adj_3_14, input wire adj_3_15,
    input wire adj_4_0, input wire adj_4_1, input wire adj_4_2, input wire adj_4_3, input wire adj_4_4, input wire adj_4_5, input wire adj_4_6, input wire adj_4_7,
    input wire adj_4_8, input wire adj_4_9, input wire adj_4_10, input wire adj_4_11, input wire adj_4_12, input wire adj_4_13, input wire adj_4_14, input wire adj_4_15,
    input wire adj_5_0, input wire adj_5_1, input wire adj_5_2, input wire adj_5_3, input wire adj_5_4, input wire adj_5_5, input wire adj_5_6, input wire adj_5_7,
    input wire adj_5_8, input wire adj_5_9, input wire adj_5_10, input wire adj_5_11, input wire adj_5_12, input wire adj_5_13, input wire adj_5_14, input wire adj_5_15,
    input wire adj_6_0, input wire adj_6_1, input wire adj_6_2, input wire adj_6_3, input wire adj_6_4, input wire adj_6_5, input wire adj_6_6, input wire adj_6_7,
    input wire adj_6_8, input wire adj_6_9, input wire adj_6_10, input wire adj_6_11, input wire adj_6_12, input wire adj_6_13, input wire adj_6_14, input wire adj_6_15,
    input wire adj_7_0, input wire adj_7_1, input wire adj_7_2, input wire adj_7_3, input wire adj_7_4, input wire adj_7_5, input wire adj_7_6, input wire adj_7_7,
    input wire adj_7_8, input wire adj_7_9, input wire adj_7_10, input wire adj_7_11, input wire adj_7_12, input wire adj_7_13, input wire adj_7_14, input wire adj_7_15,
    input wire adj_8_0, input wire adj_8_1, input wire adj_8_2, input wire adj_8_3, input wire adj_8_4, input wire adj_8_5, input wire adj_8_6, input wire adj_8_7,
    input wire adj_8_8, input wire adj_8_9, input wire adj_8_10, input wire adj_8_11, input wire adj_8_12, input wire adj_8_13, input wire adj_8_14, input wire adj_8_15,
    input wire adj_9_0, input wire adj_9_1, input wire adj_9_2, input wire adj_9_3, input wire adj_9_4, input wire adj_9_5, input wire adj_9_6, input wire adj_9_7,
    input wire adj_9_8, input wire adj_9_9, input wire adj_9_10, input wire adj_9_11, input wire adj_9_12, input wire adj_9_13, input wire adj_9_14, input wire adj_9_15,
    input wire adj_10_0, input wire adj_10_1, input wire adj_10_2, input wire adj_10_3, input wire adj_10_4, input wire adj_10_5, input wire adj_10_6, input wire adj_10_7,
    input wire adj_10_8, input wire adj_10_9, input wire adj_10_10, input wire adj_10_11, input wire adj_10_12, input wire adj_10_13, input wire adj_10_14, input wire adj_10_15,
    input wire adj_11_0, input wire adj_11_1, input wire adj_11_2, input wire adj_11_3, input wire adj_11_4, input wire adj_11_5, input wire adj_11_6, input wire adj_11_7,
    input wire adj_11_8, input wire adj_11_9, input wire adj_11_10, input wire adj_11_11, input wire adj_11_12, input wire adj_11_13, input wire adj_11_14, input wire adj_11_15,
    input wire adj_12_0, input wire adj_12_1, input wire adj_12_2, input wire adj_12_3, input wire adj_12_4, input wire adj_12_5, input wire adj_12_6, input wire adj_12_7,
    input wire adj_12_8, input wire adj_12_9, input wire adj_12_10, input wire adj_12_11, input wire adj_12_12, input wire adj_12_13, input wire adj_12_14, input wire adj_12_15,
    input wire adj_13_0, input wire adj_13_1, input wire adj_13_2, input wire adj_13_3, input wire adj_13_4, input wire adj_13_5, input wire adj_13_6, input wire adj_13_7,
    input wire adj_13_8, input wire adj_13_9, input wire adj_13_10, input wire adj_13_11, input wire adj_13_12, input wire adj_13_13, input wire adj_13_14, input wire adj_13_15,
    input wire adj_14_0, input wire adj_14_1, input wire adj_14_2, input wire adj_14_3, input wire adj_14_4, input wire adj_14_5, input wire adj_14_6, input wire adj_14_7,
    input wire adj_14_8, input wire adj_14_9, input wire adj_14_10, input wire adj_14_11, input wire adj_14_12, input wire adj_14_13, input wire adj_14_14, input wire adj_14_15,
    input wire adj_15_0, input wire adj_15_1, input wire adj_15_2, input wire adj_15_3, input wire adj_15_4, input wire adj_15_5, input wire adj_15_6, input wire adj_15_7,
    input wire adj_15_8, input wire adj_15_9, input wire adj_15_10, input wire adj_15_11, input wire adj_15_12, input wire adj_15_13, input wire adj_15_14, input wire adj_15_15,
    output reg done,
    output reg [3:0] k,
    output reg [3:0] matching_0_0, output reg [3:0] matching_0_1, output reg [3:0] matching_0_2, output reg [3:0] matching_0_3,
    output reg [3:0] matching_0_4, output reg [3:0] matching_0_5, output reg [3:0] matching_0_6, output reg [3:0] matching_0_7,
    output reg [3:0] matching_0_8, output reg [3:0] matching_0_9, output reg [3:0] matching_0_10, output reg [3:0] matching_0_11,
    output reg [3:0] matching_0_12, output reg [3:0] matching_0_13, output reg [3:0] matching_0_14, output reg [3:0] matching_0_15,
    output reg [3:0] matching_1_0, output reg [3:0] matching_1_1, output reg [3:0] matching_1_2, output reg [3:0] matching_1_3,
    output reg [3:0] matching_1_4, output reg [3:0] matching_1_5, output reg [3:0] matching_1_6, output reg [3:0] matching_1_7,
    output reg [3:0] matching_1_8, output reg [3:0] matching_1_9, output reg [3:0] matching_1_10, output reg [3:0] matching_1_11,
    output reg [3:0] matching_1_12, output reg [3:0] matching_1_13, output reg [3:0] matching_1_14, output reg [3:0] matching_1_15,
    output reg [3:0] matching_2_0, output reg [3:0] matching_2_1, output reg [3:0] matching_2_2, output reg [3:0] matching_2_3,
    output reg [3:0] matching_2_4, output reg [3:0] matching_2_5, output reg [3:0] matching_2_6, output reg [3:0] matching_2_7,
    output reg [3:0] matching_2_8, output reg [3:0] matching_2_9, output reg [3:0] matching_2_10, output reg [3:0] matching_2_11,
    output reg [3:0] matching_2_12, output reg [3:0] matching_2_13, output reg [3:0] matching_2_14, output reg [3:0] matching_2_15,
    output reg [3:0] matching_3_0, output reg [3:0] matching_3_1, output reg [3:0] matching_3_2, output reg [3:0] matching_3_3,
    output reg [3:0] matching_3_4, output reg [3:0] matching_3_5, output reg [3:0] matching_3_6, output reg [3:0] matching_3_7,
    output reg [3:0] matching_3_8, output reg [3:0] matching_3_9, output reg [3:0] matching_3_10, output reg [3:0] matching_3_11,
    output reg [3:0] matching_3_12, output reg [3:0] matching_3_13, output reg [3:0] matching_3_14, output reg [3:0] matching_3_15,
    output reg [3:0] matching_4_0, output reg [3:0] matching_4_1, output reg [3:0] matching_4_2, output reg [3:0] matching_4_3,
    output reg [3:0] matching_4_4, output reg [3:0] matching_4_5, output reg [3:0] matching_4_6, output reg [3:0] matching_4_7,
    output reg [3:0] matching_4_8, output reg [3:0] matching_4_9, output reg [3:0] matching_4_10, output reg [3:0] matching_4_11,
    output reg [3:0] matching_4_12, output reg [3:0] matching_4_13, output reg [3:0] matching_4_14, output reg [3:0] matching_4_15,
    output reg [3:0] matching_5_0, output reg [3:0] matching_5_1, output reg [3:0] matching_5_2, output reg [3:0] matching_5_3,
    output reg [3:0] matching_5_4, output reg [3:0] matching_5_5, output reg [3:0] matching_5_6, output reg [3:0] matching_5_7,
    output reg [3:0] matching_5_8, output reg [3:0] matching_5_9, output reg [3:0] matching_5_10, output reg [3:0] matching_5_11,
    output reg [3:0] matching_5_12, output reg [3:0] matching_5_13, output reg [3:0] matching_5_14, output reg [3:0] matching_5_15,
    output reg [3:0] matching_6_0, output reg [3:0] matching_6_1, output reg [3:0] matching_6_2, output reg [3:0] matching_6_3,
    output reg [3:0] matching_6_4, output reg [3:0] matching_6_5, output reg [3:0] matching_6_6, output reg [3:0] matching_6_7,
    output reg [3:0] matching_6_8, output reg [3:0] matching_6_9, output reg [3:0] matching_6_10, output reg [3:0] matching_6_11,
    output reg [3:0] matching_6_12, output reg [3:0] matching_6_13, output reg [3:0] matching_6_14, output reg [3:0] matching_6_15,
    output reg [3:0] matching_7_0, output reg [3:0] matching_7_1, output reg [3:0] matching_7_2, output reg [3:0] matching_7_3,
    output reg [3:0] matching_7_4, output reg [3:0] matching_7_5, output reg [3:0] matching_7_6, output reg [3:0] matching_7_7,
    output reg [3:0] matching_7_8, output reg [3:0] matching_7_9, output reg [3:0] matching_7_10, output reg [3:0] matching_7_11,
    output reg [3:0] matching_7_12, output reg [3:0] matching_7_13, output reg [3:0] matching_7_14, output reg [3:0] matching_7_15,
    output reg [3:0] matching_8_0, output reg [3:0] matching_8_1, output reg [3:0] matching_8_2, output reg [3:0] matching_8_3,
    output reg [3:0] matching_8_4, output reg [3:0] matching_8_5, output reg [3:0] matching_8_6, output reg [3:0] matching_8_7,
    output reg [3:0] matching_8_8, output reg [3:0] matching_8_9, output reg [3:0] matching_8_10, output reg [3:0] matching_8_11,
    output reg [3:0] matching_8_12, output reg [3:0] matching_8_13, output reg [3:0] matching_8_14, output reg [3:0] matching_8_15,
    output reg [3:0] matching_9_0, output reg [3:0] matching_9_1, output reg [3:0] matching_9_2, output reg [3:0] matching_9_3,
    output reg [3:0] matching_9_4, output reg [3:0] matching_9_5, output reg [3:0] matching_9_6, output reg [3:0] matching_9_7,
    output reg [3:0] matching_9_8, output reg [3:0] matching_9_9, output reg [3:0] matching_9_10, output reg [3:0] matching_9_11,
    output reg [3:0] matching_9_12, output reg [3:0] matching_9_13, output reg [3:0] matching_9_14, output reg [3:0] matching_9_15,
    output reg [3:0] matching_10_0, output reg [3:0] matching_10_1, output reg [3:0] matching_10_2, output reg [3:0] matching_10_3,
    output reg [3:0] matching_10_4, output reg [3:0] matching_10_5, output reg [3:0] matching_10_6, output reg [3:0] matching_10_7,
    output reg [3:0] matching_10_8, output reg [3:0] matching_10_9, output reg [3:0] matching_10_10, output reg [3:0] matching_10_11,
    output reg [3:0] matching_10_12, output reg [3:0] matching_10_13, output reg [3:0] matching_10_14, output reg [3:0] matching_10_15,
    output reg [3:0] matching_11_0, output reg [3:0] matching_11_1, output reg [3:0] matching_11_2, output reg [3:0] matching_11_3,
    output reg [3:0] matching_11_4, output reg [3:0] matching_11_5, output reg [3:0] matching_11_6, output reg [3:0] matching_11_7,
    output reg [3:0] matching_11_8, output reg [3:0] matching_11_9, output reg [3:0] matching_11_10, output reg [3:0] matching_11_11,
    output reg [3:0] matching_11_12, output reg [3:0] matching_11_13, output reg [3:0] matching_11_14, output reg [3:0] matching_11_15,
    output reg [3:0] matching_12_0, output reg [3:0] matching_12_1, output reg [3:0] matching_12_2, output reg [3:0] matching_12_3,
    output reg [3:0] matching_12_4, output reg [3:0] matching_12_5, output reg [3:0] matching_12_6, output reg [3:0] matching_12_7,
    output reg [3:0] matching_12_8, output reg [3:0] matching_12_9, output reg [3:0] matching_12_10, output reg [3:0] matching_12_11,
    output reg [3:0] matching_12_12, output reg [3:0] matching_12_13, output reg [3:0] matching_12_14, output reg [3:0] matching_12_15,
    output reg [3:0] matching_13_0, output reg [3:0] matching_13_1, output reg [3:0] matching_13_2, output reg [3:0] matching_13_3,
    output reg [3:0] matching_13_4, output reg [3:0] matching_13_5, output reg [3:0] matching_13_6, output reg [3:0] matching_13_7,
    output reg [3:0] matching_13_8, output reg [3:0] matching_13_9, output reg [3:0] matching_13_10, output reg [3:0] matching_13_11,
    output reg [3:0] matching_13_12, output reg [3:0] matching_13_13, output reg [3:0] matching_13_14, output reg [3:0] matching_13_15,
    output reg [3:0] matching_14_0, output reg [3:0] matching_14_1, output reg [3:0] matching_14_2, output reg [3:0] matching_14_3,
    output reg [3:0] matching_14_4, output reg [3:0] matching_14_5, output reg [3:0] matching_14_6, output reg [3:0] matching_14_7,
    output reg [3:0] matching_14_8, output reg [3:0] matching_14_9, output reg [3:0] matching_14_10, output reg [3:0] matching_14_11,
    output reg [3:0] matching_14_12, output reg [3:0] matching_14_13, output reg [3:0] matching_14_14, output reg [3:0] matching_14_15,
    output reg [3:0] matching_15_0, output reg [3:0] matching_15_1, output reg [3:0] matching_15_2, output reg [3:0] matching_15_3,
    output reg [3:0] matching_15_4, output reg [3:0] matching_15_5, output reg [3:0] matching_15_6, output reg [3:0] matching_15_7,
    output reg [3:0] matching_15_8, output reg [3:0] matching_15_9, output reg [3:0] matching_15_10, output reg [3:0] matching_15_11,
    output reg [3:0] matching_15_12, output reg [3:0] matching_15_13, output reg [3:0] matching_15_14, output reg [3:0] matching_15_15
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_MATCHING = 3'd1;
    localparam [2:0] STORE_MATCHING = 3'd2;
    localparam [2:0] REMOVE_EDGES = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // State registers
    reg [2:0] state, next_state;
    reg [31:0] cycle_count;
    localparam [31:0] MAX_CYCLES = 32'd5000;

    // Internal registers for adjacency matrix
    reg [15:0] adj_reg [0:15];
    integer i, j;

    // Current matching being computed
    reg [3:0] current_matching [0:15];
    reg [3:0] matching_size;

    // Stored matchings (up to 16)
    reg [3:0] stored_matchings [0:15][0:15];

    // Temporary registers for matching computation
    reg [3:0] person_assigned [0:15];
    reg [3:0] button_assigned [0:15];
    reg [3:0] current_person;
    reg [3:0] current_button;
    reg [3:0] found_count;

    // Initialize all registers on reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 32'd0;
            done <= 1'b0;
            k <= 4'd0;
            matching_size <= 4'd0;
            current_person <= 4'd0;
            current_button <= 4'd0;
            found_count <= 4'd0;

            // Initialize adjacency matrix registers
            for (i = 0; i < 16; i = i + 1) begin
                adj_reg[i] <= 16'd0;
            end

            // Initialize current matching
            for (i = 0; i < 16; i = i + 1) begin
                current_matching[i] <= 4'd0;
                person_assigned[i] <= 4'd0;
                button_assigned[i] <= 4'd0;
            end

            // Initialize stored matchings
            for (i = 0; i < 16; i = i + 1) begin
                for (j = 0; j < 16; j = j + 1) begin
                    stored_matchings[i][j] <= 4'd0;
                end
            end

            // Initialize all output matchings
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
            state <= next_state;
            cycle_count <= cycle_count + 32'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 32'd0;
                    if (start) begin
                        // Load adjacency matrix
                        adj_reg[0] <= {adj_0_15, adj_0_14, adj_0_13, adj_0_12, adj_0_11, adj_0_10, adj_0_9, adj_0_8, adj_0_7, adj_0_6, adj_0_5, adj_0_4, adj_0_3, adj_0_2, adj_0_1, adj_0_0};
                        adj_reg[1] <= {adj_1_15, adj_1_14, adj_1_13, adj_1_12, adj_1_11, adj_1_10, adj_1_9, adj_1_8, adj_1_7, adj_1_6, adj_1_5, adj_1_4, adj_1_3, adj_1_2, adj_1_1, adj_1_0};
                        adj_reg[2] <= {adj_2_15, adj_2_14, adj_2_13, adj_2_12, adj_2_11, adj_2_10, adj_2_9, adj_2_8, adj_2_7, adj_2_6, adj_2_5, adj_2_4, adj_2_3, adj_2_2, adj_2_1, adj_2_0};
                        adj_reg[3] <= {adj_3_15, adj_3_14, adj_3_13, adj_3_12, adj_3_11, adj_3_10, adj_3_9, adj_3_8, adj_3_7, adj_3_6, adj_3_5, adj_3_4, adj_3_3, adj_3_2, adj_3_1, adj_3_0};
                        adj_reg[4] <= {adj_4_15, adj_4_14, adj_4_13, adj_4_12, adj_4_11, adj_4_10, adj_4_9, adj_4_8, adj_4_7, adj_4_6, adj_4_5, adj_4_4, adj_4_3, adj_4_2, adj_4_1, adj_4_0};
                        adj_reg[5] <= {adj_5_15, adj_5_14, adj_5_13, adj_5_12, adj_5_11, adj_5_10, adj_5_9, adj_5_8, adj_5_7, adj_5_6, adj_5_5, adj_5_4, adj_5_3, adj_5_2, adj_5_1, adj_5_0};
                        adj_reg[6] <= {adj_6_15, adj_6_14, adj_6_13, adj_6_12, adj_6_11, adj_6_10, adj_6_9, adj_6_8, adj_6_7, adj_6_6, adj_6_5, adj_6_4, adj_6_3, adj_6_2, adj_6_1, adj_6_0};
                        adj_reg[7] <= {adj_7_15, adj_7_14, adj_7_13, adj_7_12, adj_7_11, adj_7_10, adj_7_9, adj_7_8, adj_7_7, adj_7_6, adj_7_5, adj_7_4, adj_7_3, adj_7_2, adj_7_1, adj_7_0};
                        adj_reg[8] <= {adj_8_15, adj_8_14, adj_8_13, adj_8_12, adj_8_11, adj_8_10, adj_8_9, adj_8_8, adj_8_7, adj_8_6, adj_8_5, adj_8_4, adj_8_3, adj_8_2, adj_8_1, adj_8_0};
                        adj_reg[9] <= {adj_9_15, adj_9_14, adj_9_13, adj_9_12, adj_9_11, adj_9_10, adj_9_9, adj_9_8, adj_9_7, adj_9_6, adj_9_5, adj_9_4, adj_9_3, adj_9_2, adj_9_1, adj_9_0};
                        adj_reg[10] <= {adj_10_15, adj_10_14, adj_10_13, adj_10_12, adj_10_11, adj_10_10, adj_10_9, adj_10_8, adj_10_7, adj_10_6, adj_10_5, adj_10_4, adj_10_3, adj_10_2, adj_10_1, adj_10_0};
                        adj_reg[11] <= {adj_11_15, adj_11_14, adj_11_13, adj_11_12, adj_11_11, adj_11_10, adj_11_9, adj_11_8, adj_11_7, adj_11_6, adj_11_5, adj_11_4, adj_11_3, adj_11_2, adj_11_1, adj_11_0};
                        adj_reg[12] <= {adj_12_15, adj_12_14, adj_12_13, adj_12_12, adj_12_11, adj_12_10, adj_12_9, adj_12_8, adj_12_7, adj_12_6, adj_12_5, adj_12_4, adj_12_3, adj_12_2, adj_12_1, adj_12_0};
                        adj_reg[13] <= {adj_13_15, adj_13_14, adj_13_13, adj_13_12, adj_13_11, adj_13_10, adj_13_9, adj_13_8, adj_13_7, adj_13_6, adj_13_5, adj_13_4, adj_13_3, adj_13_2, adj_13_1, adj_13_0};
                        adj_reg[14] <= {adj_14_15, adj_14_14, adj_14_13, adj_14_12, adj_14_11, adj_14_10, adj_14_9, adj_14_8, adj_14_7, adj_14_6, adj_14_5, adj_14_4, adj_14_3, adj_14_2, adj_14_1, adj_14_0};
                        adj_reg[15] <= {adj_15_15, adj_15_14, adj_15_13, adj_15_12, adj_15_11, adj_15_10, adj_15_9, adj_15_8, adj_15_7, adj_15_6, adj_15_5, adj_15_4, adj_15_3, adj_15_2, adj_15_1, adj_15_0};

                        // Initialize for new computation
                        k <= 4'd0;
                        matching_size <= 4'd0;
                        for (i = 0; i < 16; i = i + 1) begin
                            current_matching[i] <= 4'd0;
                            person_assigned[i] <= 4'd0;
                            button_assigned[i] <= 4'd0;
                        end
                        for (i = 0; i < 16; i = i + 1) begin
                            for (j = 0; j < 16; j = j + 1) begin
                                stored_matchings[i][j] <= 4'd0;
                            end
                        end

                        next_state <= COMPUTE_MATCHING;
                    end
                end

                COMPUTE_MATCHING: begin
                    // Simple greedy matching algorithm
                    if (current_person < n) begin
                        if (person_assigned[current_person] == 4'd0) begin
                            // Try to find an unassigned button for this person
                            for (j = 0; j < 16; j = j + 1) begin
                                if (adj_reg[current_person][j] && button_assigned[j] == 4'd0) begin
                                    current_matching[current_person] <= j + 4'd1;
                                    person_assigned[current_person] <= 4'd1;
                                    button_assigned[j] <= 4'd1;
                                    matching_size <= matching_size + 4'd1;
                                    break;
                                end
                            end
                        end
                        current_person <= current_person + 4'd1;
                        if (current_person >= n) begin
                            current_person <= 4'd0;
                            if (matching_size >= n) begin
                                next_state <= STORE_MATCHING;
                            end else begin
                                next_state <= DONE_STATE;
                            end
                        end
                    end
                end

                STORE_MATCHING: begin
                    // Store the current matching
                    for (i = 0; i < 16; i = i + 1) begin
                        stored_matchings[k][i] <= current_matching[i];
                    end
                    k <= k + 4'd1;
                    next_state <= REMOVE_EDGES;
                end

                REMOVE_EDGES: begin
                    // Remove matched edges from adjacency matrix
                    for (i = 0; i < 16; i = i + 1) begin
                        if (current_matching[i] != 4'd0) begin
                            j = current_matching[i] - 4'd1;
                            adj_reg[i][j] <= 1'b0;
                        end
                    end

                    // Reset for next matching
                    matching_size <= 4'd0;
                    for (i = 0; i < 16; i = i + 1) begin
                        current_matching[i] <= 4'd0;
                        person_assigned[i] <= 4'd0;
                        button_assigned[i] <= 4'd0;
                    end
                    current_person <= 4'd0;
                    next_state <= COMPUTE_MATCHING;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    // Output stored matchings to outputs
                    for (i = 0; i < 16; i = i + 1) begin
                        case (i)
                            4'd0: begin
                                matching_0_0 <= stored_matchings[0][0]; matching_0_1 <= stored_matchings[0][1]; matching_0_2 <= stored_matchings[0][2]; matching_0_3 <= stored_matchings[0][3];
                                matching_0_4 <= stored_matchings[0][4]; matching_0_5 <= stored_matchings[0][5]; matching_0_6 <= stored_matchings[0][6]; matching_0_7 <= stored_matchings[0][7];
                                matching_0_8 <= stored_matchings[0][8]; matching_0_9 <= stored_matchings[0][9]; matching_0_10 <= stored_matchings[0][10]; matching_0_11 <= stored_matchings[0][11];
                                matching_0_12 <= stored_matchings[0][12]; matching_0_13 <= stored_matchings[0][13]; matching_0_14 <= stored_matchings[0][14]; matching_0_15 <= stored_matchings[0][15];
                            end
                            4'd1: begin
                                matching_1_0 <= stored_matchings[1][0]; matching_1_1 <= stored_matchings[1][1]; matching_1_2 <= stored_matchings[1][2]; matching_1_3 <= stored_matchings[1][3];
                                matching_1_4 <= stored_matchings[1][4]; matching_1_5 <= stored_matchings[1][5]; matching_1_6 <= stored_matchings[1][6]; matching_1_7 <= stored_matchings[1][7];
                                matching_1_8 <= stored_matchings[1][8]; matching_1_9 <= stored_matchings[1][9]; matching_1_10 <= stored_matchings[1][10]; matching_1_11 <= stored_matchings[1][11];
                                matching_1_12 <= stored_matchings[1][12]; matching_1_13 <= stored_matchings[1][13]; matching_1_14 <= stored_matchings[1][14]; matching_1_15 <= stored_matchings[1][15];
                            end
                            4'd2: begin
                                matching_2_0 <= stored_matchings[2][0]; matching_2_1 <= stored_matchings[2][1]; matching_2_2 <= stored_matchings[2][2]; matching_2_3 <= stored_matchings[2][3];
                                matching_2_4 <= stored_matchings[2][4]; matching_2_5 <= stored_matchings[2][5]; matching_2_6 <= stored_matchings[2][6]; matching_2_7 <= stored_matchings[2][7];
                                matching_2_8 <= stored_matchings[2][8]; matching_2_9 <= stored_matchings[2][9]; matching_2_10 <= stored_matchings[2][10]; matching_2_11 <= stored_matchings[2][11];
                                matching_2_12 <= stored_matchings[2][12]; matching_2_13 <= stored_matchings[2][13]; matching_2_14 <= stored_matchings[2][14]; matching_2_15 <= stored_matchings[2][15];
                            end
                            4'd3: begin
                                matching_3_0 <= stored_matchings[3][0]; matching_3_1 <= stored_matchings[3][1]; matching_3_2 <= stored_matchings[3][2]; matching_3_3 <= stored_matchings[3][3];
                                matching_3_4 <= stored_matchings[3][4]; matching_3_5 <= stored_matchings[3][5]; matching_3_6 <= stored_matchings[3][6]; matching_3_7 <= stored_matchings[3][7];
                                matching_3_8 <= stored_matchings[3][8]; matching_3_9 <= stored_matchings[3][9]; matching_3_10 <= stored_matchings[3][10]; matching_3_11 <= stored_matchings[3][11];
                                matching_3_12 <= stored_matchings[3][12]; matching_3_13 <= stored_matchings[3][13]; matching_3_14 <= stored_matchings[3][14]; matching_3_15 <= stored_matchings[3][15];
                            end
                            4'd4: begin
                                matching_4_0 <= stored_matchings[4][0]; matching_4_1 <= stored_matchings[4][1]; matching_4_2 <= stored_matchings[4][2]; matching_4_3 <= stored_matchings[4][3];
                                matching_4_4 <= stored_matchings[4][4]; matching_4_5 <= stored_matchings[4][5]; matching_4_6 <= stored_matchings[4][6]; matching_4_7 <= stored_matchings[4][7];
                                matching_4_8 <= stored_matchings[4][8]; matching_4_9 <= stored_matchings[4][9]; matching_4_10 <= stored_matchings[4][10]; matching_4_11 <= stored_matchings[4][11];
                                matching_4_12 <= stored_matchings[4][12]; matching_4_13 <= stored_matchings[4][13]; matching_4_14 <= stored_matchings[4][14]; matching_4_15 <= stored_matchings[4][15];
                            end
                            4'd5: begin
                                matching_5_0 <= stored_matchings[5][0]; matching_5_1 <= stored_matchings[5][1]; matching_5_2 <= stored_matchings[5][2]; matching_5_3 <= stored_matchings[5][3];
                                matching_5_4 <= stored_matchings[5][4]; matching_5_5 <= stored_matchings[5][5]; matching_5_6 <= stored_matchings[5][6]; matching_5_7 <= stored_matchings[5][7];
                                matching_5_8 <= stored_matchings[5][8]; matching_5_9 <= stored_matchings[5][9]; matching_5_10 <= stored_matchings[5][10]; matching_5_11 <= stored_matchings[5][11];
                                matching_5_12 <= stored_matchings[5][12]; matching_5_13 <= stored_matchings[5][13]; matching_5_14 <= stored_matchings[5][14]; matching_5_15 <= stored_matchings[5][15];
                            end
                            4'd6: begin
                                matching_6_0 <= stored_matchings[6][0]; matching_6_1 <= stored_matchings[6][1]; matching_6_2 <= stored_matchings[6][2]; matching_6_3 <= stored_matchings[6][3];
                                matching_6_4 <= stored_matchings[6][4]; matching_6_5 <= stored_matchings[6][5]; matching_6_6 <= stored_matchings[6][6]; matching_6_7 <= stored_matchings[6][7];
                                matching_6_8 <= stored_matchings[6][8]; matching_6_9 <= stored_matchings[6][9]; matching_6_10 <= stored_matchings[6][10]; matching_6_11 <= stored_matchings[6][11];
                                matching_6_12 <= stored_matchings[6][12]; matching_6_13 <= stored_matchings[6][13]; matching_6_14 <= stored_matchings[6][14]; matching_6_15 <= stored_matchings[6][15];
                            end
                            4'd7: begin
                                matching_7_0 <= stored_matchings[7][0]; matching_7_1 <= stored_matchings[7][1]; matching_7_2 <= stored_matchings[7][2]; matching_7_3 <= stored_matchings[7][3];
                                matching_7_4 <= stored_matchings[7][4]; matching_7_5 <= stored_matchings[7][5]; matching_7_6 <= stored_matchings[7][6]; matching_7_7 <= stored_matchings[7][7];
                                matching_7_8 <= stored_matchings[7][8]; matching_7_9 <= stored_matchings[7][9]; matching_7_10 <= stored_matchings[7][10]; matching_7_11 <= stored_matchings[7][11];
                                matching_7_12 <= stored_matchings[7][12]; matching_7_13 <= stored_matchings[7][13]; matching_7_14 <= stored_matchings[7][14]; matching_7_15 <= stored_matchings[7][15];
                            end
                            4'd8: begin
                                matching_8_0 <= stored_matchings[8][0]; matching_8_1 <= stored_matchings[8][1]; matching_8_2 <= stored_matchings[8][2]; matching_8_3 <= stored_matchings[8][3];
                                matching_8_4 <= stored_matchings[8][4]; matching_8_5 <= stored_matchings[8][5]; matching_8_6 <= stored_matchings[8][6]; matching_8_7 <= stored_matchings[8][7];
                                matching_8_8 <= stored_matchings[8][8]; matching_8_9 <= stored_matchings[8][9]; matching_8_10 <= stored_matchings[8][10]; matching_8_11 <= stored_matchings[8][11];
                                matching_8_12 <= stored_matchings[8][12]; matching_8_13 <= stored_matchings[8][13]; matching_8_14 <= stored_matchings[8][14]; matching_8_15 <= stored_matchings[8][15];
                            end
                            4'd9: begin
                                matching_9_0 <= stored_matchings[9][0]; matching_9_1 <= stored_matchings[9][1]; matching_9_2 <= stored_matchings[9][2]; matching_9_3 <= stored_matchings[9][3];
                                matching_9_4 <= stored_matchings[9][4]; matching_9_5 <= stored_matchings[9][5]; matching_9_6 <= stored_matchings[9][6]; matching_9_7 <= stored_matchings[9][7];
                                matching_9_8 <= stored_matchings[9][8]; matching_9_9 <= stored_matchings[9][9]; matching_9_10 <= stored_matchings[9][10]; matching_9_11 <= stored_matchings[9][11];
                                matching_9_12 <= stored_matchings[9][12]; matching_9_13 <= stored_matchings[9][13]; matching_9_14 <= stored_matchings[9][14]; matching_9_15 <= stored_matchings[9][15];
                            end
                            4'd10: begin
                                matching_10_0 <= stored_matchings[10][0]; matching_10_1 <= stored_matchings[10][1]; matching_10_2 <= stored_matchings[10][2]; matching_10_3 <= stored_matchings[10][3];
                                matching_10_4 <= stored_matchings[10][4]; matching_10_5 <= stored_matchings[10][5]; matching_10_6 <= stored_matchings[10][6]; matching_10_7 <= stored_matchings[10][7];
                                matching_10_8 <= stored_matchings[10][8]; matching_10_9 <= stored_matchings[10][9]; matching_10_10 <= stored_matchings[10][10]; matching_10_11 <= stored_matchings[10][11];
                                matching_10_12 <= stored_matchings[10][12]; matching_10_13 <= stored_matchings[10][13]; matching_10_14 <= stored_matchings[10][14]; matching_10_15 <= stored_matchings[10][15];
                            end
                            4'd11: begin
                                matching_11_0 <= stored_matchings[11][0]; matching_11_1 <= stored_matchings[11][1]; matching_11_2 <= stored_matchings[11][2]; matching_11_3 <= stored_matchings[11][3];
                                matching_11_4 <= stored_matchings[11][4]; matching_11_5 <= stored_matchings[11][5]; matching_11_6 <= stored_matchings[11][6]; matching_11_7 <= stored_matchings[11][7];
                                matching_11_8 <= stored_matchings[11][8]; matching_11_9 <= stored_matchings[11][9]; matching_11_10 <= stored_matchings[11][10]; matching_11_11 <= stored_matchings[11][11];
                                matching_11_12 <= stored_matchings[11][12]; matching_11_13 <= stored_matchings[11][13]; matching_11_14 <= stored_matchings[11][14]; matching_11_15 <= stored_matchings[11][15];
                            end
                            4'd12: begin
                                matching_12_0 <= stored_matchings[12][0]; matching_12_1 <= stored_matchings[12][1]; matching_12_2 <= stored_matchings[12][2]; matching_12_3 <= stored_matchings[12][3];
                                matching_12_4 <= stored_matchings[12][4]; matching_12_5 <= stored_matchings[12][5]; matching_12_6 <= stored_matchings[12][6]; matching_12_7 <= stored_matchings[12][7];
                                matching_12_8 <= stored_matchings[12][8]; matching_12_9 <= stored_matchings[12][9]; matching_12_10 <= stored_matchings[12][10]; matching_12_11 <= stored_matchings[12][11];
                                matching_12_12 <= stored_matchings[12][12]; matching_12_13 <= stored_matchings[12][13]; matching_12_14 <= stored_matchings[12][14]; matching_12_15 <= stored_matchings[12][15];
                            end
                            4'd13: begin
                                matching_13_0 <= stored_matchings[13][0]; matching_13_1 <= stored_matchings[13][1]; matching_13_2 <= stored_matchings[13][2]; matching_13_3 <= stored_matchings[13][3];
                                matching_13_4 <= stored_matchings[13][4]; matching_13_5 <= stored_matchings[13][5]; matching_13_6 <= stored_matchings[13][6]; matching_13_7 <= stored_matchings[13][7];
                                matching_13_8 <= stored_matchings[13][8]; matching_13_9 <= stored_matchings[13][9]; matching_13_10 <= stored_matchings[13][10]; matching_13_11 <= stored_matchings[13][11];
                                matching_13_12 <= stored_matchings[13][12]; matching_13_13 <= stored_matchings[13][13]; matching_13_14 <= stored_matchings[13][14]; matching_13_15 <= stored_matchings[13][15];
                            end
                            4'd14: begin
                                matching_14_0 <= stored_matchings[14][0]; matching_14_1 <= stored_matchings[14][1]; matching_14_2 <= stored_matchings[14][2]; matching_14_3 <= stored_matchings[14][3];
                                matching_14_4 <= stored_matchings[14][4]; matching_14_5 <= stored_matchings[14][5]; matching_14_6 <= stored_matchings[14][6]; matching_14_7 <= stored_matchings[14][7];
                                matching_14_8 <= stored_matchings[14][8]; matching_14_9 <= stored_matchings[14][9]; matching_14_10 <= stored_matchings[14][10]; matching_14_11 <= stored_matchings[14][11];
                                matching_14_12 <= stored_matchings[14][12]; matching_14_13 <= stored_matchings[14][13]; matching_14_14 <= stored_matchings[14][14]; matching_14_15 <= stored_matchings[14][15];
                            end
                            4'd15: begin
                                matching_15_0 <= stored_matchings[15][0]; matching_15_1 <= stored_matchings[15][1]; matching_15_2 <= stored_matchings[15][2]; matching_15_3 <= stored_matchings[15][3];
                                matching_15_4 <= stored_matchings[15][4]; matching_15_5 <= stored_matchings[15][5]; matching_15_6 <= stored_matchings[15][6]; matching_15_7 <= stored_matchings[15][7];
                                matching_15_8 <= stored_matchings[15][8]; matching_15_9 <= stored_matchings[15][9]; matching_15_10 <= stored_matchings[15][10]; matching_15_11 <= stored_matchings[15][11];
                                matching_15_12 <= stored_matchings[15][12]; matching_15_13 <= stored_matchings[15][13]; matching_15_14 <= stored_matchings[15][14]; matching_15_15 <= stored_matchings[15][15];
                            end
                        endcase
                    end
                    next_state <= IDLE;
                end

                default: next_state <= IDLE;
            endcase

            // Timeout check
            if (cycle_count >= MAX_CYCLES) begin
                next_state <= DONE_STATE;
            end
        end
    end
endmodule