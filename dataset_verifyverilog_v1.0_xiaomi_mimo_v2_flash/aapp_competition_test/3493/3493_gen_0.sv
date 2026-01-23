module maximum_disjoint_matchings (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] adj_flat,
    output reg [2:0] k,
    output reg [47:0] assignments_packed,
    output reg done
);

// State machine
localparam [2:0] IDLE = 3'b000;
localparam [2:0] RESET = 3'b001;
localparam [2:0] FIND_MATCHING = 3'b010;
localparam [2:0] FOUND = 3'b011;
localparam [2:0] UPDATE = 3'b100;
localparam [2:0] DONE_STATE = 3'b101;

reg [2:0] state, next_state;

// Internal registers
reg [15:0] available_edges;
reg [2:0] k_reg;
reg [47:0] assignments_packed_reg;

// Permutation ROM (24 permutations of 4 buttons)
reg [11:0] permutations_0;
reg [11:0] permutations_1;
reg [11:0] permutations_2;
reg [11:0] permutations_3;
reg [11:0] permutations_4;
reg [11:0] permutations_5;
reg [11:0] permutations_6;
reg [11:0] permutations_7;
reg [11:0] permutations_8;
reg [11:0] permutations_9;
reg [11:0] permutations_10;
reg [11:0] permutations_11;
reg [11:0] permutations_12;
reg [11:0] permutations_13;
reg [11:0] permutations_14;
reg [11:0] permutations_15;
reg [11:0] permutations_16;
reg [11:0] permutations_17;
reg [11:0] permutations_18;
reg [11:0] permutations_19;
reg [11:0] permutations_20;
reg [11:0] permutations_21;
reg [11:0] permutations_22;
reg [11:0] permutations_23;

// Permutation checking
reg [4:0] perm_index;
reg [1:0] check_index;
reg valid_perm;
reg [11:0] current_perm;

// Initialize permutations (all possible perfect matchings for n=4)
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        permutations_0 <= 12'b000_001_010_011; // [0,1,2,3]
        permutations_1 <= 12'b000_001_011_010; // [0,1,3,2]
        permutations_2 <= 12'b000_010_001_011; // [0,2,1,3]
        permutations_3 <= 12'b000_010_011_001; // [0,2,3,1]
        permutations_4 <= 12'b000_011_001_010; // [0,3,1,2]
        permutations_5 <= 12'b000_011_010_001; // [0,3,2,1]
        permutations_6 <= 12'b001_000_010_011; // [1,0,2,3]
        permutations_7 <= 12'b001_000_011_010; // [1,0,3,2]
        permutations_8 <= 12'b001_010_000_011; // [1,2,0,3]
        permutations_9 <= 12'b001_010_011_000; // [1,2,3,0]
        permutations_10 <= 12'b001_011_000_010; // [1,3,0,2]
        permutations_11 <= 12'b001_011_010_000; // [1,3,2,0]
        permutations_12 <= 12'b010_000_001_011; // [2,0,1,3]
        permutations_13 <= 12'b010_000_011_001; // [2,0,3,1]
        permutations_14 <= 12'b010_001_000_011; // [2,1,0,3]
        permutations_15 <= 12'b010_001_011_000; // [2,1,3,0]
        permutations_16 <= 12'b010_011_000_001; // [2,3,0,1]
        permutations_17 <= 12'b010_011_001_000; // [2,3,1,0]
        permutations_18 <= 12'b011_000_001_010; // [3,0,1,2]
        permutations_19 <= 12'b011_000_010_001; // [3,0,2,1]
        permutations_20 <= 12'b011_001_000_010; // [3,1,0,2]
        permutations_21 <= 12'b011_001_010_000; // [3,1,2,0]
        permutations_22 <= 12'b011_010_000_001; // [3,2,0,1]
        permutations_23 <= 12'b011_010_001_000; // [3,2,1,0]
    end
end

// State transition
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
    end else begin
        state <= next_state;
    end
end

// Next state logic
always @(*) begin
    case (state)
        IDLE: begin
            if (start) next_state = RESET;
            else next_state = IDLE;
        end
        RESET: next_state = FIND_MATCHING;
        FIND_MATCHING: begin
            if (valid_perm) next_state = FOUND;
            else if (perm_index == 5'd23) next_state = DONE_STATE;
            else next_state = FIND_MATCHING;
        end
        FOUND: next_state = UPDATE;
        UPDATE: begin
            if (available_edges == 16'b0) next_state = DONE_STATE;
            else next_state = FIND_MATCHING;
        end
        DONE_STATE: next_state = DONE_STATE;
        default: next_state = IDLE;
    endcase
end

// Output logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        k <= 3'b0;
        assignments_packed <= 48'b0;
        done <= 1'b0;
        available_edges <= 16'b0;
        k_reg <= 3'b0;
        assignments_packed_reg <= 48'b0;
        perm_index <= 5'b0;
        check_index <= 2'b0;
        valid_perm <= 1'b0;
        current_perm <= 12'b0;
    end else begin
        case (state)
            RESET: begin
                available_edges <= adj_flat;
                k_reg <= 3'b0;
                assignments_packed_reg <= 48'b0;
                perm_index <= 5'b0;
                check_index <= 2'b0;
                valid_perm <= 1'b0;
                done <= 1'b0;
            end
            FIND_MATCHING: begin
                if (perm_index < 5'd24) begin
                    case (perm_index)
                        5'd0: current_perm <= permutations_0;
                        5'd1: current_perm <= permutations_1;
                        5'd2: current_perm <= permutations_2;
                        5'd3: current_perm <= permutations_3;
                        5'd4: current_perm <= permutations_4;
                        5'd5: current_perm <= permutations_5;
                        5'd6: current_perm <= permutations_6;
                        5'd7: current_perm <= permutations_7;
                        5'd8: current_perm <= permutations_8;
                        5'd9: current_perm <= permutations_9;
                        5'd10: current_perm <= permutations_10;
                        5'd11: current_perm <= permutations_11;
                        5'd12: current_perm <= permutations_12;
                        5'd13: current_perm <= permutations_13;
                        5'd14: current_perm <= permutations_14;
                        5'd15: current_perm <= permutations_15;
                        5'd16: current_perm <= permutations_16;
                        5'd17: current_perm <= permutations_17;
                        5'd18: current_perm <= permutations_18;
                        5'd19: current_perm <= permutations_19;
                        5'd20: current_perm <= permutations_20;
                        5'd21: current_perm <= permutations_21;
                        5'd22: current_perm <= permutations_22;
                        5'd23: current_perm <= permutations_23;
                        default: current_perm <= permutations_0;
                    endcase
                    // Check if current permutation is valid
                    if (check_index == 2'd3) begin
                        // All 4 buttons checked
                        if (valid_perm) begin
                            valid_perm <= 1'b1;
                        end else begin
                            valid_perm <= 1'b0;
                        end
                        perm_index <= perm_index + 5'd1;
                        check_index <= 2'd0;
                    end else begin
                        // Check one button
                        case (check_index)
                            2'd0: begin // button 0
                                valid_perm <= (available_edges[(current_perm[2:0]*4'd4 + 4'd0)] && 
                                             (current_perm[2:0] != current_perm[5:3]) && 
                                             (current_perm[2:0] != current_perm[8:6]) && 
                                             (current_perm[2:0] != current_perm[11:9]));
                            end
                            2'd1: begin // button 1
                                if (valid_perm) begin
                                    valid_perm <= (available_edges[(current_perm[5:3]*4'd4 + 4'd1)] && 
                                                 (current_perm[5:3] != current_perm[8:6]) && 
                                                 (current_perm[5:3] != current_perm[11:9]));
                                end
                            end
                            2'd2: begin // button 2
                                if (valid_perm) begin
                                    valid_perm <= (available_edges[(current_perm[8:6]*4'd4 + 4'd2)] && 
                                                 (current_perm[8:6] != current_perm[11:9]));
                                end
                            end
                            2'd3: begin // button 3
                                if (valid_perm) begin
                                    valid_perm <= available_edges[(current_perm[11:9]*4'd4 + 4'd3)];
                                end
                            end
                        endcase
                        check_index <= check_index + 2'd1;
                    end
                end
            end
            FOUND: begin
                // Record the matching
                if (k_reg < 3'd4) begin
                    case (k_reg)
                        3'd0: assignments_packed_reg[11:0] <= current_perm;
                        3'd1: assignments_packed_reg[23:12] <= current_perm;
                        3'd2: assignments_packed_reg[35:24] <= current_perm;
                        3'd3: assignments_packed_reg[47:36] <= current_perm;
                    endcase
                    k_reg <= k_reg + 3'd1;
                end
            end
            UPDATE: begin
                // Remove the edges used in the current matching
                available_edges[(current_perm[2:0]*4'd4 + 4'd0)] <= 1'b0;
                available_edges[(current_perm[5:3]*4'd4 + 4'd1)] <= 1'b0;
                available_edges[(current_perm[8:6]*4'd4 + 4'd2)] <= 1'b0;
                available_edges[(current_perm[11:9]*4'd4 + 4'd3)] <= 1'b0;
                // Reset for next search
                perm_index <= 5'b0;
                check_index <= 2'b0;
                valid_perm <= 1'b0;
            end
            DONE_STATE: begin
                k <= k_reg;
                assignments_packed <= assignments_packed_reg;
                done <= 1'b1;
            end
            default: begin
                k <= 3'b0;
                assignments_packed <= 48'b0;
                done <= 1'b0;
            end
        endcase
    end
end

endmodule