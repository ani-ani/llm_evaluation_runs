module MinimumCostReach(
    input clk,
    input rst_n,
    input start,
    input signed [15:0] card_r,
    input signed [15:0] card_c,
    input signed [15:0] card_a,
    input signed [15:0] card_b,
    input [15:0] card_p,
    input [3:0] card_idx,
    input card_valid,
    input calc,
    output reg [15:0] min_cost,
    output reg done,
    output reg possible
);

    // Card storage: 16 entries of 16-bit signed for positions/offsets, 16-bit unsigned for price
    reg signed [15:0] r_reg [0:15];
    reg signed [15:0] c_reg [0:15];
    reg signed [15:0] a_reg [0:15];
    reg signed [15:0] b_reg [0:15];
    reg [15:0] p_reg [0:15];
    
    // Internal state variables
    reg [15:0] owned_mask;
    reg [15:0] current_cost;
    reg signed [15:0] current_r;
    reg signed [15:0] current_c;
    
    // Algorithm control
    reg [3:0] iter_idx;       // For iterating through cards
    reg [2:0] state;
    reg [3:0] last_owned_count;
    reg [7:0] cycle_timeout;
    reg [2:0] search_state;   // Sub-state for search/buy process
    
    // Reachability calculation helpers
    reg signed [31:0] diff_r;
    reg signed [31:0] diff_c;
    reg signed [31:0] abs_diff_r;
    reg signed [31:0] abs_diff_c;
    reg signed [31:0] temp_a;
    reg signed [31:0] temp_b;
    reg is_reachable;
    reg [3:0] owned_idx;
    reg signed [15:0] check_a;
    reg signed [15:0] check_b;
    
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] CALC_BUY = 3'd2;
    localparam [2:0] CHECK_GOAL = 3'd3;
    localparam [2:0] FINISHED = 3'd4;
    
    // Search sub-states
    localparam [2:0] SEARCH_IDLE = 3'd0;
    localparam [2:0] SEARCH_CHECK = 3'd1;
    localparam [2:0] SEARCH_BUY = 3'd2;
    localparam [2:0] SEARCH_NEXT = 3'd3;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            min_cost <= 16'd0;
            done <= 1'b0;
            possible <= 1'b0;
            state <= IDLE;
            cycle_timeout <= 8'd0;
            
            // Clear card storage
            for (i = 0; i < 16; i = i + 1) begin
                r_reg[i] <= 16'd0;
                c_reg[i] <= 16'd0;
                a_reg[i] <= 16'd0;
                b_reg[i] <= 16'd0;
                p_reg[i] <= 16'd0;
            end
            
            owned_mask <= 16'd0;
            current_cost <= 16'd0;
            current_r <= 16'd0;
            current_c <= 16'd0;
            iter_idx <= 4'd0;
            last_owned_count <= 4'd0;
            search_state <= SEARCH_IDLE;
            
            is_reachable <= 1'b0;
            owned_idx <= 4'd0;
            check_a <= 16'd0;
            check_b <= 16'd0;
            diff_r <= 32'd0;
            diff_c <= 32'd0;
            abs_diff_r <= 32'd0;
            abs_diff_c <= 32'd0;
            temp_a <= 32'd0;
            temp_b <= 32'd0;
        end else begin
            done <= 1'b0;  // Pulse done only when set
            
            case (state)
                IDLE: begin
                    if (start) begin
                        // Reset algorithm state
                        owned_mask <= 16'd0;
                        current_cost <= 16'd0;
                        current_r <= 16'd0;
                        current_c <= 16'd0;
                        iter_idx <= 4'd0;
                        last_owned_count <= 4'd0;
                        cycle_timeout <= 8'd0;
                        search_state <= SEARCH_IDLE;
                        state <= LOAD;
                    end
                end
                
                LOAD: begin
                    if (card_valid) begin
                        // Load card data into registers
                        r_reg[card_idx] <= card_r;
                        c_reg[card_idx] <= card_c;
                        a_reg[card_idx] <= card_a;
                        b_reg[card_idx] <= card_b;
                        p_reg[card_idx] <= card_p;
                    end
                    if (calc) begin
                        // Start calculation
                        // Knight starts at card 0's position
                        current_r <= r_reg[0];
                        current_c <= c_reg[0];
                        owned_mask <= 16'h0001;  // Own card 0
                        current_cost <= p_reg[0];
                        state <= CALC_BUY;
                        iter_idx <= 4'd1;  // Start checking from card 1
                        search_state <= SEARCH_CHECK;
                    end
                end
                
                CALC_BUY: begin
                    // Iterate through cards to find purchasable ones
                    cycle_timeout <= cycle_timeout + 8'd1;
                    
                    if (cycle_timeout >= 8'd200) begin
                        // Timeout fallback
                        state <= CHECK_GOAL;
                    end else begin
                        case (search_state)
                            SEARCH_CHECK: begin
                                if (iter_idx >= 4'd16) begin
                                    // Finished iteration, check if bought anything
                                    if (last_owned_count != count_ones(owned_mask)) begin
                                        // New card bought, restart search
                                        last_owned_count <= count_ones(owned_mask);
                                        iter_idx <= 4'd1;
                                        search_state <= SEARCH_CHECK;
                                    end else begin
                                        // No new cards bought, proceed to goal check
                                        state <= CHECK_GOAL;
                                    end
                                end else begin
                                    // Check if card is already owned
                                    if (owned_mask[iter_idx]) begin
                                        // Owned, skip
                                        iter_idx <= iter_idx + 4'd1;
                                        search_state <= SEARCH_CHECK;
                                    end else begin
                                        // Not owned, check reachability
                                        diff_r <= r_reg[iter_idx] - current_r;
                                        diff_c <= c_reg[iter_idx] - current_c;
                                        search_state <= SEARCH_CHECK;
                                        search_state <= SEARCH_IDLE; // Jump to calculation
                                        is_reachable <= 1'b0;
                                        owned_idx <= 4'd0;
                                        check_a <= 16'd0;
                                        check_b <= 16'd0;
                                    end
                                end
                            end
                            
                            SEARCH_IDLE: begin
                                // Calculate absolute differences
                                if (diff_r[31]) abs_diff_r <= -diff_r; else abs_diff_r <= diff_r;
                                if (diff_c[31]) abs_diff_c <= -diff_c; else abs_diff_c <= diff_c;
                                
                                // Start checking owned cards
                                owned_idx <= 4'd0;
                                search_state <= SEARCH_NEXT;
                            end
                            
                            SEARCH_NEXT: begin
                                // Find next owned card to check moves
                                if (owned_idx >= 4'd16) begin
                                    // No move from any owned card reaches target
                                    if (is_reachable) begin
                                        search_state <= SEARCH_BUY;
                                    end else begin
                                        iter_idx <= iter_idx + 4'd1;
                                        search_state <= SEARCH_CHECK;
                                    end
                                end else begin
                                    // Check if this card is owned
                                    if (owned_mask[owned_idx]) begin
                                        check_a <= a_reg[owned_idx];
                                        check_b <= b_reg[owned_idx];
                                        search_state <= SEARCH_IDLE + 3'd1; // Transition to calculation
                                    end else begin
                                        owned_idx <= owned_idx + 4'd1;
                                    end
                                end
                            end
                            
                            SEARCH_IDLE + 3'd1: begin // REACH_CALC
                                // Check if diff is a linear combo of (a,b) and (b,a)
                                // Simplification: Check if diff matches 1-step move from this card
                                // From (a,b): moves are (+/-a, +/-b), (+/-b, +/-a)
                                
                                // Check (diff_r, diff_c) == (a, b), (a, -b), (-a, b), (-a, -b)
                                if (((diff_r == check_a) && (diff_c == check_b)) ||
                                    ((diff_r == check_a) && (diff_c == -check_b)) ||
                                    ((diff_r == -check_a) && (diff_c == check_b)) ||
                                    ((diff_r == -check_a) && (diff_c == -check_b)) ||
                                    ((diff_r == check_b) && (diff_c == check_a)) ||
                                    ((diff_r == check_b) && (diff_c == -check_a)) ||
                                    ((diff_r == -check_b) && (diff_c == check_a)) ||
                                    ((diff_r == -check_b) && (diff_c == -check_a))) begin
                                    is_reachable <= 1'b1;
                                end
                                
                                owned_idx <= owned_idx + 4'd1;
                                search_state <= SEARCH_NEXT;
                            end
                            
                            SEARCH_BUY: begin
                                // Buy the card
                                current_cost <= current_cost + p_reg[iter_idx];
                                current_r <= r_reg[iter_idx];
                                current_c <= c_reg[iter_idx];
                                owned_mask[iter_idx] <= 1'b1;
                                
                                // Reset iteration
                                iter_idx <= 4'd1;
                                last_owned_count <= count_ones(owned_mask) + 4'd1;
                                search_state <= SEARCH_CHECK;
                            end
                            
                            default: search_state <= SEARCH_CHECK;
                        endcase
                    end
                end
                
                CHECK_GOAL: begin
                    // Check if (0,0) is reachable from current position with current moves
                    diff_r <= 0 - current_r;
                    diff_c <= 0 - current_c;
                    search_state <= SEARCH_IDLE;
                    state <= FINISHED;
                end
                
                FINISHED: begin
                    // Determine reachability and set output
                    // We re-use the reachability logic from SEARCH_IDLE
                    
                    case (search_state)
                        SEARCH_IDLE: begin
                            if (diff_r[31]) abs_diff_r <= -diff_r; else abs_diff_r <= diff_r;
                            if (diff_c[31]) abs_diff_c <= -diff_c; else abs_diff_c <= diff_c;
                            is_reachable <= 1'b0;
                            owned_idx <= 4'd0;
                            search_state <= SEARCH_NEXT;
                        end
                        
                        SEARCH_NEXT: begin
                            if (owned_idx >= 4'd16) begin
                                // Done checking
                                min_cost <= current_cost;
                                possible <= is_reachable;
                                done <= 1'b1;
                                state <= IDLE;
                            end else begin
                                if (owned_mask[owned_idx]) begin
                                    check_a <= a_reg[owned_idx];
                                    check_b <= b_reg[owned_idx];
                                    search_state <= SEARCH_IDLE + 3'd1; // REACH_CALC
                                end else begin
                                    owned_idx <= owned_idx + 4'd1;
                                end
                            end
                        end
                        
                        SEARCH_IDLE + 3'd1: begin // REACH_CALC
                            // Check if (0,0) is reachable
                            if (((diff_r == check_a) && (diff_c == check_b)) ||
                                ((diff_r == check_a) && (diff_c == -check_b)) ||
                                ((diff_r == -check_a) && (diff_c == check_b)) ||
                                ((diff_r == -check_a) && (diff_c == -check_b)) ||
                                ((diff_r == check_b) && (diff_c == check_a)) ||
                                ((diff_r == check_b) && (diff_c == -check_a)) ||
                                ((diff_r == -check_b) && (diff_c == check_a)) ||
                                ((diff_r == -check_b) && (diff_c == -check_a))) begin
                                is_reachable <= 1'b1;
                            end
                            
                            owned_idx <= owned_idx + 4'd1;
                            search_state <= SEARCH_NEXT;
                        end
                        
                        default: search_state <= SEARCH_NEXT;
                    endcase
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    // Helper function to count set bits in a mask (Verilog doesn't support built-in)
    function automatic [3:0] count_ones;
        input [15:0] mask;
        begin
            count_ones = 4'd0;
            if (mask[0]) count_ones = count_ones + 4'd1;
            if (mask[1]) count_ones = count_ones + 4'd1;
            if (mask[2]) count_ones = count_ones + 4'd1;
            if (mask[3]) count_ones = count_ones + 4'd1;
            if (mask[4]) count_ones = count_ones + 4'd1;
            if (mask[5]) count_ones = count_ones + 4'd1;
            if (mask[6]) count_ones = count_ones + 4'd1;
            if (mask[7]) count_ones = count_ones + 4'd1;
            if (mask[8]) count_ones = count_ones + 4'd1;
            if (mask[9]) count_ones = count_ones + 4'd1;
            if (mask[10]) count_ones = count_ones + 4'd1;
            if (mask[11]) count_ones = count_ones + 4'd1;
            if (mask[12]) count_ones = count_ones + 4'd1;
            if (mask[13]) count_ones = count_ones + 4'd1;
            if (mask[14]) count_ones = count_ones + 4'd1;
            if (mask[15]) count_ones = count_ones + 4'd1;
        end
    endfunction

endmodule