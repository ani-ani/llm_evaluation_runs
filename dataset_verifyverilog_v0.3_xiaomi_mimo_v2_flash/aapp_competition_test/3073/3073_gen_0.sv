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
localparam [3:0] IDLE = 4'd0;
localparam [3:0] CHECK_SUBSET = 4'd1;
localparam [3:0] CALC_COST = 4'd2;
localparam [3:0] UPDATE_MIN = 4'd3;
localparam [3:0] NEXT_SUBSET = 4'd4;
localparam [3:0] FINISHED = 4'd5;

// Internal registers
reg [3:0] state;
reg [MAX_CARDS-1:0] subset;
reg [RESULT_WIDTH-1:0] min_cost;
reg [RESULT_WIDTH-1:0] current_cost;
reg subset_valid;
reg [7:0] cycle_counter;
localparam [7:0] MAX_CYCLES = 8'd200;

// GCD computation registers
reg [31:0] gcd_a;
reg [31:0] gcd_b;
reg [31:0] gcd_result;
reg gcd_done;
reg gcd_start;
reg [2:0] gcd_state;
localparam [2:0] GCD_IDLE = 3'd0;
localparam [2:0] GCD_COMPUTE = 3'd1;
localparam [2:0] GCD_DONE = 3'd2;

// Helper wires
wire signed [COORD_WIDTH-1:0] start_r = card_r[0];
wire signed [COORD_WIDTH-1:0] start_c = card_c[0];

// Integer registers for GCD computation (combinational logic will be in always block)
reg [31:0] temp_gcd_a;
reg [31:0] temp_gcd_b;
reg [31:0] temp_result;
reg [31:0] card_gcd_val;
reg [31:0] combined_gcd;
reg first_card_flag;
reg [31:0] target_r_abs;
reg [31:0] target_c_abs;

// Combinational block to check subset validity and compute cost
always @(*) begin
    // Default values
    subset_valid = 1'b0;
    current_cost = {RESULT_WIDTH{1'b0}};
    
    // Check if subset includes card 0 (start card)
    if (subset[0] == 1'b0) begin
        subset_valid = 1'b0;
    end else begin
        // Compute total cost of subset
        current_cost = {RESULT_WIDTH{1'b0}};
        for (integer i = 0; i < MAX_CARDS; i = i + 1) begin
            if (i < num_cards && subset[i]) begin
                current_cost = current_cost + card_p[i];
            end
        end
        
        // Simplified reachability check using GCD
        // Initialize GCD computation
        first_card_flag = 1'b1;
        combined_gcd = 32'd0;
        
        // Compute GCD of all relevant move components
        for (integer i = 0; i < MAX_CARDS; i = i + 1) begin
            if (i < num_cards && subset[i]) begin
                // Compute gcd(a, b), gcd(a+b), gcd(a-b)
                temp_gcd_a = (card_a[i] < 0) ? -card_a[i] : card_a[i];
                temp_gcd_b = (card_b[i] < 0) ? -card_b[i] : card_b[i];
                
                // Compute gcd(a, b)
                if (temp_gcd_b == 0) begin
                    card_gcd_val = temp_gcd_a;
                end else begin
                    temp_result = temp_gcd_b;
                    temp_gcd_b = temp_gcd_a % temp_gcd_b;
                    temp_gcd_a = temp_result;
                    while (temp_gcd_b != 0) begin
                        temp_result = temp_gcd_b;
                        temp_gcd_b = temp_gcd_a % temp_gcd_b;
                        temp_gcd_a = temp_result;
                    end
                    card_gcd_val = temp_gcd_a;
                end
                
                // Combine with existing GCD
                if (first_card_flag) begin
                    combined_gcd = card_gcd_val;
                    first_card_flag = 1'b0;
                end else begin
                    temp_gcd_a = combined_gcd;
                    temp_gcd_b = card_gcd_val;
                    if (temp_gcd_b == 0) begin
                        combined_gcd = temp_gcd_a;
                    end else begin
                        temp_result = temp_gcd_b;
                        temp_gcd_b = temp_gcd_a % temp_gcd_b;
                        temp_gcd_a = temp_result;
                        while (temp_gcd_b != 0) begin
                            temp_result = temp_gcd_b;
                            temp_gcd_b = temp_gcd_a % temp_gcd_b;
                            temp_gcd_a = temp_result;
                        end
                        combined_gcd = temp_gcd_a;
                    end
                end
            end
        end
        
        // If no cards or GCD is 0, reject
        if (first_card_flag || combined_gcd == 32'd0) begin
            subset_valid = 1'b0;
        end else begin
            // Check if target offset is divisible by GCD
            integer target_r = -start_r;
            integer target_c = -start_c;
            
            // Ensure non-negative for modulo operation
            if (target_r < 0) target_r_abs = -target_r;
            else target_r_abs = target_r;
            
            if (target_c < 0) target_c_abs = -target_c;
            else target_c_abs = target_c;
            
            // Check divisibility: both coordinates must be divisible by GCD
            if ((target_r_abs % combined_gcd == 0) && (target_c_abs % combined_gcd == 0)) begin
                subset_valid = 1'b1;
            end else begin
                subset_valid = 1'b0;
            end
        end
    end
end

// State machine sequential logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        subset <= {MAX_CARDS{1'b0}};
        min_cost <= {RESULT_WIDTH{1'b1}};
        result <= {RESULT_WIDTH{1'b0}};
        done <= 1'b0;
        cycle_counter <= 8'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                cycle_counter <= 8'd0;
                if (start && num_cards > 3'd0) begin
                    subset <= {MAX_CARDS{1'b0}};
                    min_cost <= {RESULT_WIDTH{1'b1}};
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
                cycle_counter <= cycle_counter + 8'd1;
            end
            
            CALC_COST: begin
                // Cost already computed in combinational block
                state <= UPDATE_MIN;
                cycle_counter <= cycle_counter + 8'd1;
            end
            
            UPDATE_MIN: begin
                if (current_cost < min_cost) begin
                    min_cost <= current_cost;
                end
                state <= NEXT_SUBSET;
                cycle_counter <= cycle_counter + 8'd1;
            end
            
            NEXT_SUBSET: begin
                subset <= subset + 1;
                state <= CHECK_SUBSET;
                cycle_counter <= cycle_counter + 8'd1;
            end
            
            FINISHED: begin
                if (min_cost == {RESULT_WIDTH{1'b1}}) begin
                    // No valid subset found, output -1
                    result <= {RESULT_WIDTH{1'b1}};
                end else begin
                    result <= min_cost;
                end
                done <= 1'b1;
                state <= IDLE;
                cycle_counter <= cycle_counter + 8'd1;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule