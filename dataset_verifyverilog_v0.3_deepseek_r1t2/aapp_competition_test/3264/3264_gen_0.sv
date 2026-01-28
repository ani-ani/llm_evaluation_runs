module mirko_slavko #(
    parameter MOD = 1000000000,
    parameter MAX_N = 8,
    parameter CUTS = 7,
    parameter STATES = 128
) (
    input clk,
    input rst_n,
    input start,
    input [3:0] N,        // 1..8
    output reg done,
    output reg [29:0] result
);

// Precomputed coprime pairs
localparam MAX_PAIRS = 21;
reg [2:0] pair_i [0:20];
reg [2:0] pair_j [0:20];
reg [6:0] pair_mask [0:20];

// State machine declarations
localparam [2:0] IDLE        = 3'd0;
localparam [2:0] LOAD_PAIR   = 3'd1;
localparam [2:0] COPY_DP     = 3'd2;
localparam [2:0] PROCESS_MASK= 3'd3;
localparam [2:0] UPDATE      = 3'd4;
localparam [2:0] DONE_STATE  = 3'd5;

reg [2:0] state, next_state;
reg [4:0] pair_index, next_pair_index;
reg [6:0] mask_index, next_mask_index;

// DP arrays
reg [29:0] dp [0:127];
reg [29:0] next_dp [0:127];

// Full mask for given N
reg [6:0] full_mask;

// Addition helper
wire [29:0] add_a  = dp[mask_index];
wire [29:0] add_b  = next_dp[mask_index | pair_mask[pair_index]];
wire [29:0] add_sum = add_a + add_b;
wire [29:0] add_mod = (add_sum >= MOD) ? (add_sum - MOD) : add_sum;

integer i; // Loop variable

// Pair initialization (synthesis-time constants)
initial begin
    // Initialize pair arrays here (removed for brevity)
    // ... (same initialization as original code)
end

// Full mask combinational logic
always @(*) begin
    full_mask = 7'd0;
    if (N >= 4'd1) full_mask = full_mask | (7'b1 << (N-4'd1));
end

// Next state combinational logic
always @(*) begin
    next_state = state;
    next_pair_index = pair_index;
    next_mask_index = mask_index;
    done = 1'b0;
    
    case(state)
        IDLE: begin
            if (start) begin
                next_state = LOAD_PAIR;
                next_pair_index = 5'd0;
            end
        end
        
        LOAD_PAIR: begin
            if (pair_index >= MAX_PAIRS) begin
                next_state = DONE_STATE;
            end else if (pair_i[pair_index] > N || pair_j[pair_index] > N) begin
                next_pair_index = pair_index + 5'd1;
                next_state = LOAD_PAIR;
            end else begin
                next_mask_index = 7'd0;
                next_state = COPY_DP;
            end
        end
        
        COPY_DP: begin
            if (mask_index == (STATES-1)) begin
                next_mask_index = 7'd0;
                next_state = PROCESS_MASK;
            end else begin
                next_mask_index = mask_index + 7'd1;
            end
        end
        
        PROCESS_MASK: begin
            if (mask_index == (STATES-1)) begin
                next_state = UPDATE;
            end else begin
                next_mask_index = mask_index + 7'd1;
            end
        end
        
        UPDATE: begin
            next_pair_index = pair_index + 5'd1;
            next_state = LOAD_PAIR;
        end
        
        DONE_STATE: begin
            done = 1'b1;
        end
        
        default: next_state = IDLE;
    endcase
end

// Sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        pair_index <= 5'd0;
        mask_index <= 7'd0;
        done <= 1'b0;
        result <= 30'd0;
        
        for (i=0; i<STATES; i=i+1) begin
            dp[i] <= 30'd0;
            next_dp[i] <= 30'd0;
        end
    end else begin
        state <= next_state;
        pair_index <= next_pair_index;
        mask_index <= next_mask_index;

        case(state)
            IDLE: begin
                if (start) begin
                    // Clear DP arrays
                    for (i=0; i<STATES; i=i+1) begin
                        dp[i] <= (i == 0) ? 30'd1 : 30'd0;
                        next_dp[i] <= 30'd0;
                    end
                end
            end
            
            COPY_DP: begin
                next_dp[mask_index] <= dp[mask_index];
            end
            
            PROCESS_MASK: begin
                if (add_a != 30'd0) begin
                    next_dp[mask_index | pair_mask[pair_index]] <= add_mod;
                end
            end
            
            UPDATE: begin
                for (i=0; i<STATES; i=i+1) begin
                    dp[i] <= next_dp[i];
                    next_dp[i] <= 30'd0;
                end
            end
            
            DONE_STATE: begin
                if (full_mask == 7'd0) begin
                    result <= (dp[0] >= 30'd1) ? (dp[0] - 30'd1) : (dp[0] + MOD - 30'd1);
                end else begin
                    result <= dp[full_mask];
                end
            end
        endcase
    end
end

endmodule