module min_cost_module(
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

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LOAD = 2'd1;
    localparam [1:0] CALC = 2'd2;
    localparam [1:0] DONE = 2'd3;
    
    reg [1:0] state, next_state;
    
    // Card storage (16 cards max)
    reg signed [15:0] cards_r [0:15];
    reg signed [15:0] cards_c [0:15];
    reg signed [15:0] cards_a [0:15];
    reg signed [15:0] cards_b [0:15];
    reg [15:0] cards_p [0:15];
    
    // Internal registers
    reg [15:0] owned_mask;
    reg [15:0] current_cost;
    reg signed [15:0] current_r, current_c;
    reg [3:0] card_counter;
    reg [7:0] cycle_count;
    reg found_new_card;
    reg [3:0] new_card_idx;
    
    // Constants
    localparam [7:0] MAX_CYCLES = 8'd100;
    localparam [3:0] MAX_CARDS = 4'd16;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            
            // Initialize card storage
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                cards_r[i] <= 16'd0;
                cards_c[i] <= 16'd0;
                cards_a[i] <= 16'd0;
                cards_b[i] <= 16'd0;
                cards_p[i] <= 16'd0;
            end
            
            // Initialize internal registers
            owned_mask <= 16'd0;
            current_cost <= 16'd0;
            current_r <= 16'd0;
            current_c <= 16'd0;
            card_counter <= 4'd0;
            cycle_count <= 8'd0;
            found_new_card <= 1'b0;
            new_card_idx <= 4'd0;
            
            // Initialize outputs
            min_cost <= 16'd0;
            done <= 1'b0;
            possible <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    possible <= 1'b0;
                    
                    if (start) begin
                        next_state <= LOAD;
                    end
                end
                
                LOAD: begin
                    if (card_valid) begin
                        cards_r[card_idx] <= card_r;
                        cards_c[card_idx] <= card_c;
                        cards_a[card_idx] <= card_a;
                        cards_b[card_idx] <= card_b;
                        cards_p[card_idx] <= card_p;
                    end
                    
                    if (calc) begin
                        // Initialize for calculation
                        owned_mask <= {15'b0, 1'b1}; // Own card 0
                        current_cost <= cards_p[0];
                        current_r <= cards_r[0];
                        current_c <= cards_c[0];
                        card_counter <= 4'd0;
                        cycle_count <= 8'd0;
                        next_state <= CALC;
                    end
                end
                
                CALC: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if we can reach (0,0) with current moves
                    if (can_reach_zero()) begin
                        min_cost <= current_cost;
                        possible <= 1'b1;
                        next_state <= DONE;
                    end else if (cycle_count >= MAX_CYCLES) begin
                        // Timeout - impossible
                        min_cost <= 16'd0;
                        possible <= 1'b0;
                        next_state <= DONE;
                    end else begin
                        // Try to find a new card we can reach
                        found_new_card <= 1'b0;
                        new_card_idx <= 4'd0;
                        
                        integer i;
                        for (i = 0; i < 16; i = i + 1) begin
                            if (!owned_mask[i] && can_reach_card(i)) begin
                                found_new_card <= 1'b1;
                                new_card_idx <= i;
                                break;
                            end
                        end
                        
                        if (found_new_card) begin
                            // Buy the card
                            owned_mask[new_card_idx] <= 1'b1;
                            current_cost <= current_cost + cards_p[new_card_idx];
                            current_r <= cards_r[new_card_idx];
                            current_c <= cards_c[new_card_idx];
                        end else begin
                            // No new cards reachable - impossible
                            min_cost <= 16'd0;
                            possible <= 1'b0;
                            next_state <= DONE;
                        end
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end

    // Helper function: Check if we can reach (0,0) from current position
    function can_reach_zero;
        input [15:0] mask;
        input signed [15:0] r, c;
        
        integer i;
        for (i = 0; i < 16; i = i + 1) begin
            if (mask[i]) begin
                // Check all 8 possible moves from this card
                if ((r + cards_a[i] == 0) && (c + cards_b[i] == 0)) begin
                    can_reach_zero = 1'b1;
                    return;
                end
                if ((r - cards_a[i] == 0) && (c + cards_b[i] == 0)) begin
                    can_reach_zero = 1'b1;
                    return;
                end
                if ((r + cards_a[i] == 0) && (c - cards_b[i] == 0)) begin
                    can_reach_zero = 1'b1;
                    return;
                end
                if ((r - cards_a[i] == 0) && (c - cards_b[i] == 0)) begin
                    can_reach_zero = 1'b1;
                    return;
                end
                if ((r + cards_b[i] == 0) && (c + cards_a[i] == 0)) begin
                    can_reach_zero = 1'b1;
                    return;
                end
                if ((r - cards_b[i] == 0) && (c + cards_a[i] == 0)) begin
                    can_reach_zero = 1'b1;
                    return;
                end
                if ((r + cards_b[i] == 0) && (c - cards_a[i] == 0)) begin
                    can_reach_zero = 1'b1;
                    return;
                end
                if ((r - cards_b[i] == 0) && (c - cards_a[i] == 0)) begin
                    can_reach_zero = 1'b1;
                    return;
                end
            end
        end
        
        can_reach_zero = 1'b0;
    endfunction

    // Helper function: Check if we can reach card i from current position
    function can_reach_card;
        input [3:0] card_idx;
        input [15:0] mask;
        input signed [15:0] r, c;
        
        integer i;
        for (i = 0; i < 16; i = i + 1) begin
            if (mask[i]) begin
                // Check all 8 possible moves from this card
                if ((r + cards_a[i] == cards_r[card_idx]) && (c + cards_b[i] == cards_c[card_idx])) begin
                    can_reach_card = 1'b1;
                    return;
                end
                if ((r - cards_a[i] == cards_r[card_idx]) && (c + cards_b[i] == cards_c[card_idx])) begin
                    can_reach_card = 1'b1;
                    return;
                end
                if ((r + cards_a[i] == cards_r[card_idx]) && (c - cards_b[i] == cards_c[card_idx])) begin
                    can_reach_card = 1'b1;
                    return;
                end
                if ((r - cards_a[i] == cards_r[card_idx]) && (c - cards_b[i] == cards_c[card_idx])) begin
                    can_reach_card = 1'b1;
                    return;
                end
                if ((r + cards_b[i] == cards_r[card_idx]) && (c + cards_a[i] == cards_c[card_idx])) begin
                    can_reach_card = 1'b1;
                    return;
                end
                if ((r - cards_b[i] == cards_r[card_idx]) && (c + cards_a[i] == cards_c[card_idx])) begin
                    can_reach_card = 1'b1;
                    return;
                end
                if ((r + cards_b[i] == cards_r[card_idx]) && (c - cards_a[i] == cards_c[card_idx])) begin
                    can_reach_card = 1'b1;
                    return;
                end
                if ((r - cards_b[i] == cards_r[card_idx]) && (c - cards_a[i] == cards_c[card_idx])) begin
                    can_reach_card = 1'b1;
                    return;
                end
            end
        end
        
        can_reach_card = 1'b0;
    endfunction

endmodule