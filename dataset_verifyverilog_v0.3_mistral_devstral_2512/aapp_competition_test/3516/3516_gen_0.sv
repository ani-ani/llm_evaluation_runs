module prince_of_python #(
    parameter N = 3,
    parameter DATA_WIDTH = 16,
    parameter ITEM_WIDTH = 4,
    localparam NUM_ITEMS = N + 1,
    localparam DP_SIZE = 1 << N,
    localparam INF = (1 << DATA_WIDTH) - 1
)(
    input clk,
    input rst_n,
    input start,
    // Level 0
    input [ITEM_WIDTH-1:0] x_0,
    input [DATA_WIDTH-1:0] s_0,
    input [DATA_WIDTH-1:0] a_0_0,
    input [DATA_WIDTH-1:0] a_0_1,
    input [DATA_WIDTH-1:0] a_0_2,
    input [DATA_WIDTH-1:0] a_0_3,
    // Level 1
    input [ITEM_WIDTH-1:0] x_1,
    input [DATA_WIDTH-1:0] s_1,
    input [DATA_WIDTH-1:0] a_1_0,
    input [DATA_WIDTH-1:0] a_1_1,
    input [DATA_WIDTH-1:0] a_1_2,
    input [DATA_WIDTH-1:0] a_1_3,
    // Level 2
    input [ITEM_WIDTH-1:0] x_2,
    input [DATA_WIDTH-1:0] s_2,
    input [DATA_WIDTH-1:0] a_2_0,
    input [DATA_WIDTH-1:0] a_2_1,
    input [DATA_WIDTH-1:0] a_2_2,
    input [DATA_WIDTH-1:0] a_2_3,
    output reg [DATA_WIDTH-1:0] result,
    output reg done
);
    // Internal storage for inputs
    reg [ITEM_WIDTH-1:0] x_reg [0:N-1];
    reg [DATA_WIDTH-1:0] s_reg [0:N-1];
    reg [DATA_WIDTH-1:0] a_reg [0:N-1][0:NUM_ITEMS-1];
    
    // DP array
    reg [DATA_WIDTH-1:0] dp [0:DP_SIZE-1];
    
    // State machine
    reg [3:0] state, next_state;
    localparam [3:0] S_IDLE = 4'd0;
    localparam [3:0] S_LOAD_INPUTS = 4'd1;
    localparam [3:0] S_INIT_DP = 4'd2;
    localparam [3:0] S_LOOP_MASK = 4'd3;
    localparam [3:0] S_START_LEVELS = 4'd4;
    localparam [3:0] S_PROCESS_LEVELS = 4'd5;
    localparam [3:0] S_UPDATE_DP = 4'd6;
    localparam [3:0] S_NEXT_LEVEL = 4'd7;
    localparam [3:0] S_NEXT_MASK = 4'd8;
    localparam [3:0] S_DONE = 4'd9;
    
    // Counters
    reg [N-1:0] mask_counter;
    reg [2:0] level_counter; // enough for N<=8
    
    // Combinational signals
    wire [ITEM_WIDTH-1:0] max_item;
    wire shortcut_avail;
    wire [DATA_WIDTH-1:0] cost;
    wire [DATA_WIDTH-1:0] new_dp;
    wire [N-1:0] new_mask;
    
    // Helper function to get max item from mask
    function automatic [ITEM_WIDTH-1:0] get_max_item;
        input [N-1:0] mask;
        integer i;
        begin
            get_max_item = 0;
            for (i = 0; i < N; i = i + 1) begin
                if (mask[i]) get_max_item = i+1;
            end
        end
    endfunction
    
    assign max_item = get_max_item(mask_counter);
    
    // Determine if shortcut is available
    assign shortcut_avail = (x_reg[level_counter] == 0) || 
                           (x_reg[level_counter] > 0 && mask_counter[x_reg[level_counter]-1]);
    
    // Compute cost
    assign cost = shortcut_avail ? s_reg[level_counter] : a_reg[level_counter][max_item];
    
    // New mask after adding level
    assign new_mask = mask_counter | (1 << level_counter);
    
    // New DP value
    assign new_dp = dp[mask_counter] + cost;
    
    // State transition and output logic
    always @(*) begin
        next_state = state; // default stay in current state
        
        case (state)
            S_IDLE: begin
                if (start) next_state = S_LOAD_INPUTS;
            end
            
            S_LOAD_INPUTS: begin
                next_state = S_INIT_DP;
            end
            
            S_INIT_DP: begin
                next_state = S_LOOP_MASK;
            end
            
            S_LOOP_MASK: begin
                if (mask_counter == DP_SIZE) next_state = S_DONE;
                else if (dp[mask_counter] == INF) next_state = S_NEXT_MASK;
                else next_state = S_START_LEVELS;
            end
            
            S_START_LEVELS: begin
                next_state = S_PROCESS_LEVELS;
            end
            
            S_PROCESS_LEVELS: begin
                if (level_counter == N) next_state = S_NEXT_MASK;
                else if (mask_counter[level_counter] == 0) next_state = S_UPDATE_DP;
                else next_state = S_NEXT_LEVEL;
            end
            
            S_UPDATE_DP: begin
                next_state = S_NEXT_LEVEL;
            end
            
            S_NEXT_LEVEL: begin
                if (level_counter + 1 == N) next_state = S_NEXT_MASK;
                else next_state = S_PROCESS_LEVELS;
            end
            
            S_NEXT_MASK: begin
                next_state = S_LOOP_MASK;
            end
            
            S_DONE: begin
                // stay in done state
            end
            
            default: next_state = S_IDLE;
        endcase
    end
    
    // Sequential logic
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            result <= 0;
            done <= 0;
            mask_counter <= 0;
            level_counter <= 0;
            // Reset dp
            for (i = 0; i < DP_SIZE; i = i + 1) dp[i] <= INF;
        end else begin
            state <= next_state;
            
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    result <= 0;
                end
                
                S_LOAD_INPUTS: begin
                    // Copy inputs to internal registers
                    x_reg[0] <= x_0; x_reg[1] <= x_1; x_reg[2] <= x_2;
                    s_reg[0] <= s_0; s_reg[1] <= s_1; s_reg[2] <= s_2;
                    a_reg[0][0] <= a_0_0; a_reg[0][1] <= a_0_1; a_reg[0][2] <= a_0_2; a_reg[0][3] <= a_0_3;
                    a_reg[1][0] <= a_1_0; a_reg[1][1] <= a_1_1; a_reg[1][2] <= a_1_2; a_reg[1][3] <= a_1_3;
                    a_reg[2][0] <= a_2_0; a_reg[2][1] <= a_2_1; a_reg[2][2] <= a_2_2; a_reg[2][3] <= a_2_3;
                end
                
                S_INIT_DP: begin
                    dp[0] <= 0;
                    for (i = 1; i < DP_SIZE; i = i + 1) dp[i] <= INF;
                    mask_counter <= 0;
                    level_counter <= 0;
                end
                
                S_LOOP_MASK: begin
                    // nothing to do here
                end
                
                S_START_LEVELS: begin
                    level_counter <= 0;
                end
                
                S_PROCESS_LEVELS: begin
                    // nothing to do here
                end
                
                S_UPDATE_DP: begin
                    // Update dp[new_mask] if new_dp is smaller
                    if (new_dp < dp[new_mask]) begin
                        dp[new_mask] <= new_dp;
                    end
                end
                
                S_NEXT_LEVEL: begin
                    level_counter <= level_counter + 1;
                end
                
                S_NEXT_MASK: begin
                    mask_counter <= mask_counter + 1;
                end
                
                S_DONE: begin
                    done <= 1'b1;
                    result <= dp[DP_SIZE-1];
                end
            endcase
        end
    end
endmodule