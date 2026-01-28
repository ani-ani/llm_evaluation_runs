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
localparam [2:0] IDLE = 3'd0;
localparam [2:0] RESET = 3'd1;
localparam [2:0] FIND_MATCHING = 3'd2;
localparam [2:0] FOUND = 3'd3;
localparam [2:0] UPDATE = 3'd4;
localparam [2:0] DONE_STATE = 3'd5;

reg [2:0] state, next_state;

// Internal registers
reg [15:0] available_edges;
reg [2:0] k_reg;
reg [47:0] assignments_packed_reg;

// Permutation ROM (24 permutations of 4 buttons)
reg [11:0] permutations [0:23];

// Permutation checking
reg [4:0] perm_index;
reg [1:0] check_index;
reg valid_perm;
reg [11:0] current_perm;

integer i;

// Initialize permutations (this will create a ROM)
always @(posedge clk) begin
    if (!rst_n) begin
        permutations[0] <= 12'b000_001_010_011;
        permutations[1] <= 12'b000_001_011_010;
        permutations[2] <= 12'b000_010_001_011;
        permutations[3] <= 12'b000_010_011_001;
        permutations[4] <= 12'b000_011_001_010;
        permutations[5] <= 12'b000_011_010_001;
        permutations[6] <= 12'b001_000_010_011;
        permutations[7] <= 12'b001_000_011_010;
        permutations[8] <= 12'b001_010_000_011;
        permutations[9] <= 12'b001_010_011_000;
        permutations[10] <= 12'b001_011_000_010;
        permutations[11] <= 12'b001_011_010_000;
        permutations[12] <= 12'b010_000_001_011;
        permutations[13] <= 12'b010_000_011_001;
        permutations[14] <= 12'b010_001_000_011;
        permutations[15] <= 12'b010_001_011_000;
        permutations[16] <= 12'b010_011_000_001;
        permutations[17] <= 12'b010_011_001_000;
        permutations[18] <= 12'b011_000_001_010;
        permutations[19] <= 12'b011_000_010_001;
        permutations[20] <= 12'b011_001_000_010;
        permutations[21] <= 12'b011_001_010_000;
        permutations[22] <= 12'b011_010_000_001;
        permutations[23] <= 12'b011_010_001_000;
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
    next_state = state;
    case (state)
        IDLE: next_state = start ? RESET : IDLE;
        RESET: next_state = FIND_MATCHING;
        FIND_MATCHING: begin
            if (valid_perm) next_state = FOUND;
            else if (perm_index == 5'd23) next_state = DONE_STATE;
            else next_state = FIND_MATCHING;
        end
        FOUND: next_state = UPDATE;
        UPDATE: begin
            if (available_edges == 16'd0) next_state = DONE_STATE;
            else next_state = FIND_MATCHING;
        end
        DONE_STATE: next_state = DONE_STATE;
        default: next_state = IDLE;
    endcase
end

// Output logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        k <= 3'd0;
        assignments_packed <= 48'd0;
        done <= 1'b0;
        available_edges <= 16'd0;
        k_reg <= 3'd0;
        assignments_packed_reg <= 48'd0;
        perm_index <= 5'd0;
        check_index <= 2'd0;
        valid_perm <= 1'b0;
        current_perm <= 12'd0;
        
        for (i = 0; i < 24; i = i + 1) begin
            permutations[i] <= 12'd0;
        end
    end else begin
        case (state)
            IDLE: done <= 1'b0;
            
            RESET: begin
                available_edges <= adj_flat;
                k_reg <= 3'd0;
                assignments_packed_reg <= 48'd0;
                perm_index <= 5'd0;
                check_index <= 2'd0;
                valid_perm <= 1'b0;
            end
            
            FIND_MATCHING: begin
                if (perm_index < 5'd24) begin
                    if (check_index == 2'd3) begin
                        if (valid_perm) begin
                            valid_perm <= 1'b1;
                        end else begin
                            perm_index <= perm_index + 5'd1;
                            check_index <= 2'd0;
                            current_perm <= permutations[perm_index + 5'd1];
                        end
                    end else begin
                        case (check_index)
                            2'd0: valid_perm <= 
                                ((available_edges[current_perm[2:0] * 4 + 0]) && 
                                (current_perm[2:0] != current_perm[5:3]) && 
                                (current_perm[2:0] != current_perm[8:6]) && 
                                (current_perm[2:0] != current_perm[11:9]));
                                
                            2'd1: valid_perm <= valid_perm &&
                                ((available_edges[current_perm[5:3] * 4 + 1]) && 
                                (current_perm[5:3] != current_perm[8:6]) && 
                                (current_perm[5:3] != current_perm[11:9]));
                                
                            2'd2: valid_perm <= valid_perm &&
                                ((available_edges[current_perm[8:6] * 4 + 2]) &&
                                (current_perm[8:6] != current_perm[11:9]));
                                
                            2'd3: valid_perm <= valid_perm &&
                                (available_edges[current_perm[11:9] * 4 + 3]);
                        endcase
                        check_index <= check_index + 2'd1;
                    end
                end
            end
            
            FOUND: begin
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
                available_edges[current_perm[2:0]*4 + 0] <= 1'b0;
                available_edges[current_perm[5:3]*4 + 1] <= 1'b0;
                available_edges[current_perm[8:6]*4 + 2] <= 1'b0;
                available_edges[current_perm[11:9]*4 + 3] <= 1'b0;
                perm_index <= 5'd0;
                check_index <= 2'd0;
                valid_perm <= 1'b0;
                current_perm <= 12'd0;
            end
            
            DONE_STATE: begin
                k <= k_reg;
                assignments_packed <= assignments_packed_reg;
                done <= 1'b1;
            end
            
            default: begin
                state <= IDLE;
            end
        endcase
    end
end

endmodule