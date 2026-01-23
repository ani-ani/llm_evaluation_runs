module mirko_slavko #(
    parameter MOD = 1000000000,
    parameter MAX_N = 8,
    parameter CUTS = 7,
    parameter STATES = 1 << CUTS, // 128
    parameter MAX_PAIRS = 21
)(
    input clk,
    input rst_n,
    input start,
    input [3:0] N,        // 1..8
    output reg done,
    output reg [29:0] result
);

// Precomputed coprime pairs for 1..8
// Each entry: i, j, mask (bits for cuts 2..8)
reg [2:0] pair_i [0:20];
reg [2:0] pair_j [0:20];
reg [6:0] pair_mask [0:20];

initial begin
    // Pair 0: (1,2) mask=0000001
    pair_i[0] = 1; pair_j[0] = 2; pair_mask[0] = 7'b0000001;
    // Pair 1: (1,3) mask=0000011
    pair_i[1] = 1; pair_j[1] = 3; pair_mask[1] = 7'b0000011;
    // Pair 2: (1,4) mask=0000111
    pair_i[2] = 1; pair_j[2] = 4; pair_mask[2] = 7'b0000111;
    // Pair 3: (1,5) mask=0001111
    pair_i[3] = 1; pair_j[3] = 5; pair_mask[3] = 7'b0001111;
    // Pair 4: (1,6) mask=0011111
    pair_i[4] = 1; pair_j[4] = 6; pair_mask[4] = 7'b0011111;
    // Pair 5: (1,7) mask=0111111
    pair_i[5] = 1; pair_j[5] = 7; pair_mask[5] = 7'b0111111;
    // Pair 6: (1,8) mask=1111111
    pair_i[6] = 1; pair_j[6] = 8; pair_mask[6] = 7'b1111111;
    // Pair 7: (2,3) mask=0000010
    pair_i[7] = 2; pair_j[7] = 3; pair_mask[7] = 7'b0000010;
    // Pair 8: (2,5) mask=0001110
    pair_i[8] = 2; pair_j[8] = 5; pair_mask[8] = 7'b0001110;
    // Pair 9: (2,7) mask=0111110
    pair_i[9] = 2; pair_j[9] = 7; pair_mask[9] = 7'b0111110;
    // Pair 10: (3,4) mask=0000100
    pair_i[10] = 3; pair_j[10] = 4; pair_mask[10] = 7'b0000100;
    // Pair 11: (3,5) mask=0001100
    pair_i[11] = 3; pair_j[11] = 5; pair_mask[11] = 7'b0001100;
    // Pair 12: (3,7) mask=0111100
    pair_i[12] = 3; pair_j[12] = 7; pair_mask[12] = 7'b0111100;
    // Pair 13: (3,8) mask=1111100
    pair_i[13] = 3; pair_j[13] = 8; pair_mask[13] = 7'b1111100;
    // Pair 14: (4,5) mask=0001000
    pair_i[14] = 4; pair_j[14] = 5; pair_mask[14] = 7'b0001000;
    // Pair 15: (4,7) mask=0111000
    pair_i[15] = 4; pair_j[15] = 7; pair_mask[15] = 7'b0111000;
    // Pair 16: (5,6) mask=0010000
    pair_i[16] = 5; pair_j[16] = 6; pair_mask[16] = 7'b0010000;
    // Pair 17: (5,7) mask=0110000
    pair_i[17] = 5; pair_j[17] = 7; pair_mask[17] = 7'b0110000;
    // Pair 18: (5,8) mask=1110000
    pair_i[18] = 5; pair_j[18] = 8; pair_mask[18] = 7'b1110000;
    // Pair 19: (6,7) mask=0100000
    pair_i[19] = 6; pair_j[19] = 7; pair_mask[19] = 7'b0100000;
    // Pair 20: (7,8) mask=1000000
    pair_i[20] = 7; pair_j[20] = 8; pair_mask[20] = 7'b1000000;
end

// Full mask for given N
reg [6:0] full_mask;
always_comb begin
    case(N)
        1: full_mask = 7'b0000000;
        2: full_mask = 7'b0000001;
        3: full_mask = 7'b0000011;
        4: full_mask = 7'b0000111;
        5: full_mask = 7'b0001111;
        6: full_mask = 7'b0011111;
        7: full_mask = 7'b0111111;
        8: full_mask = 7'b1111111;
        default: full_mask = 7'b0000000;
    endcase
end

// State machine
localparam IDLE = 3'b000;
localparam LOAD_PAIR = 3'b001;
localparam COPY_DP = 3'b010;
localparam PROCESS_MASK = 3'b011;
localparam UPDATE = 3'b100;
localparam NEXT_PAIR = 3'b101;
localparam DONE = 3'b110;

reg [2:0] state, next_state;
reg [4:0] pair_index, next_pair_index; // 0..20
reg [6:0] mask_index, next_mask_index; // 0..127

// DP arrays
reg [29:0] dp [0:STATES-1];      // current dp
reg [29:0] next_dp [0:STATES-1]; // next dp (during pair processing)

// Addition helper
wire [29:0] add_a;
wire [29:0] add_b;
wire [29:0] add_sum;
wire [29:0] add_mod;

assign add_a = dp[mask_index];
assign add_b = next_dp[mask_index | pair_mask[pair_index]];
assign add_sum = add_a + add_b;
assign add_mod = (add_sum >= MOD) ? (add_sum - MOD) : add_sum;

// Combinational next state logic
always_comb begin
    next_state = state;
    next_pair_index = pair_index;
    next_mask_index = mask_index;
    done = 0;
    
    case(state)
        IDLE: begin
            if (start) begin
                next_state = LOAD_PAIR;
                next_pair_index = 0;
            end
        end
        
        LOAD_PAIR: begin
            if (pair_index >= MAX_PAIRS) begin
                next_state = DONE;
            end else if (pair_i[pair_index] > N || pair_j[pair_index] > N) begin
                next_pair_index = pair_index + 1;
                next_state = LOAD_PAIR;
            end else begin
                // valid pair, start copying dp to next_dp
                next_mask_index = 0;
                next_state = COPY_DP;
            end
        end
        
        COPY_DP: begin
            // copy dp[mask_index] to next_dp[mask_index]
            // next_dp[mask_index] will be assigned in sequential block
            if (mask_index == STATES-1) begin
                next_mask_index = 0;
                next_state = PROCESS_MASK;
            end else begin
                next_mask_index = mask_index + 1;
            end
        end
        
        PROCESS_MASK: begin
            // For current mask_index, if dp[mask_index] != 0, add to next_dp[new_mask]
            // We'll update next_dp in sequential block based on add_mod
            if (mask_index == STATES-1) begin
                next_state = UPDATE;
            end else begin
                next_mask_index = mask_index + 1;
            end
        end
        
        UPDATE: begin
            // dp will be updated from next_dp in sequential block
            next_pair_index = pair_index + 1;
            next_state = LOAD_PAIR;
        end
        
        NEXT_PAIR: begin
            // Not used, we go directly from UPDATE to LOAD_PAIR
        end
        
        DONE: begin
            done = 1;
        end
    endcase
end

// Sequential logic
always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        pair_index <= 0;
        mask_index <= 0;
        // Reset dp
        for (int i = 0; i < STATES; i++) begin
            dp[i] <= 0;
            next_dp[i] <= 0;
        end
        result <= 0;
    end else begin
        state <= next_state;
        pair_index <= next_pair_index;
        mask_index <= next_mask_index;
        
        case(state)
            IDLE: begin
                if (start) begin
                    // Initialize dp: dp[0]=1, others 0
                    for (int i = 0; i < STATES; i++) begin
                        dp[i] <= 0;
                        next_dp[i] <= 0;
                    end
                    dp[0] <= 1;
                end
            end
            
            COPY_DP: begin
                next_dp[mask_index] <= dp[mask_index];
            end
            
            PROCESS_MASK: begin
                // Only update if dp[mask_index] != 0
                if (add_a != 0) begin
                    next_dp[mask_index | pair_mask[pair_index]] <= add_mod;
                end
            end
            
            UPDATE: begin
                // Copy next_dp to dp
                for (int i = 0; i < STATES; i++) begin
                    dp[i] <= next_dp[i];
                end
            end
            
            DONE: begin
                // Compute result = dp[full_mask]; if full_mask==0, subtract 1 (exclude empty set)
                if (full_mask == 0) begin
                    // dp[0] is 1 (empty set), so subtract 1
                    if (dp[0] >= 1)
                        result <= dp[0] - 1;
                    else
                        result <= dp[0] + MOD - 1; // should not happen
                end else begin
                    result <= dp[full_mask];
                end
            end
        endcase
    end
end

endmodule