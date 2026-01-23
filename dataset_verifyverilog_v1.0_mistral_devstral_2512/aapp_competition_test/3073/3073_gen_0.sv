module tarot_knight_min_cost #(
    parameter MAX_CARDS = 4,
    parameter COORD_WIDTH = 8,
    parameter VAL_WIDTH = 8,
    parameter PRICE_WIDTH = 16,
    parameter RESULT_WIDTH = 16
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    
    // Card data arrays - each signal is a vector of MAX_CARDS elements
    input wire signed [COORD_WIDTH-1:0] card_r [0:MAX_CARDS-1],
    input wire signed [COORD_WIDTH-1:0] card_c [0:MAX_CARDS-1],
    input wire [VAL_WIDTH-1:0] card_a [0:MAX_CARDS-1],
    input wire [VAL_WIDTH-1:0] card_b [0:MAX_CARDS-1],
    input wire [PRICE_WIDTH-1:0] card_p [0:MAX_CARDS-1],
    input wire [3:0] num_cards,  // 1 to MAX_CARDS
    
    output reg [RESULT_WIDTH-1:0] result,
    output reg done
);

// State encoding
localparam [2:0] IDLE = 3'd0;
localparam [2:0] CHECK_SUBSET = 3'd1;
localparam [2:0] CALC_COST = 3'd2;
localparam [2:0] UPDATE_MIN = 3'd3;
localparam [2:0] NEXT_SUBSET = 3'd4;
localparam [2:0] FINISHED = 3'd5;

// Internal registers
reg [2:0] state;
reg [MAX_CARDS-1:0] subset;
reg [RESULT_WIDTH-1:0] min_cost;
reg [RESULT_WIDTH-1:0] current_cost;
reg subset_valid;

// Helper wire for start position (first card)
wire signed [COORD_WIDTH-1:0] start_r = card_r[0];
wire signed [COORD_WIDTH-1:0] start_c = card_c[0];

// Combinational block to check subset validity and compute cost
always @(*) begin
    // Default values
    subset_valid = 1'b0;
    current_cost = 16'd0;
    
    // Check if subset includes card 0 (start card)
    if (subset[0] == 1'b0) begin
        subset_valid = 1'b0;
    end else begin
        // Compute total cost of subset
        integer i;
        current_cost = 16'd0;
        for (i = 0; i < MAX_CARDS; i = i + 1) begin
            if (i < num_cards && subset[i]) begin
                current_cost = current_cost + card_p[i];
            end
        end
        
        // Simplified reachability check
        // Compute GCD of all relevant move components
        integer gcd_val;
        integer first_gcd;
        first_gcd = 1'b1;
        for (i = 0; i < MAX_CARDS; i = i + 1) begin
            if (i < num_cards && subset[i]) begin
                // For card (a,b), moves include (±a,±b) and (±b,±a)
                // GCD of all coordinate changes is gcd(a,b, a+b, a-b)
                integer card_gcd = gcd_func(card_a[i], card_b[i]);
                card_gcd = gcd_func(card_gcd, card_a[i] + card_b[i]);
                card_gcd = gcd_func(card_gcd, card_a[i] - card_b[i]);
                
                if (first_gcd) begin
                    gcd_val = card_gcd;
                    first_gcd = 1'b0;
                end else begin
                    gcd_val = gcd_func(gcd_val, card_gcd);
                end
            end
        end
        
        // Check if target offset is divisible by GCD
        integer target_r = -start_r;
        integer target_c = -start_c;
        
        // Ensure non-negative for modulo operation
        if (target_r < 0) target_r = -target_r;
        if (target_c < 0) target_c = -target_c;
        
        // Simplified condition: both coordinates must be divisible by GCD
        if (target_r % gcd_val == 0 && target_c % gcd_val == 0) begin
            subset_valid = 1'b1;
        end else begin
            subset_valid = 1'b0;
        end
    end
end

// GCD function for integer arguments
function automatic integer gcd_func(input integer a, input integer b);
    integer temp;
    begin
        a = (a < 0) ? -a : a;
        b = (b < 0) ? -b : b;
        while (b != 0) begin
            temp = b;
            b = a % b;
            a = temp;
        end
        gcd_func = a;
    end
endfunction

// State machine sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        subset <= 0;
        min_cost <= 16'd0;
        result <= 16'd0;
        done <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start && num_cards > 0) begin
                    subset <= 0;
                    min_cost <= 16'd0;
                    state <= CHECK_SUBSET;
                end
            end
            
            CHECK_SUBSET: begin
                // Check if we've enumerated all subsets
                if (subset < (1 << num_cards)) begin
                    // Check current subset validity (combinational logic above)
                    if (subset_valid) begin
                        state <= CALC_COST;
                    end else begin
                        state <= NEXT_SUBSET;
                    end
                end else begin
                    state <= FINISHED;
                end
            end
            
            CALC_COST: begin
                // Cost already computed in combinational block
                state <= UPDATE_MIN;
            end
            
            UPDATE_MIN: begin
                if (current_cost < min_cost) begin
                    min_cost <= current_cost;
                end
                state <= NEXT_SUBSET;
            end
            
            NEXT_SUBSET: begin
                subset <= subset + 1;
                state <= CHECK_SUBSET;
            end
            
            FINISHED: begin
                if (min_cost == 16'd0) begin
                    // No valid subset found, output -1
                    result <= 16'd0;
                end else begin
                    result <= min_cost;
                end
                done <= 1'b1;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule