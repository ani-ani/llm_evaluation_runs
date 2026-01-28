module PotatoStoreOptimizer(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] a [0:15],
    input wire [15:0] c [0:15],
    input wire [3:0] N,
    input wire [3:0] L,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE       = 4'd0;
    localparam [3:0] LOAD       = 4'd1;
    localparam [3:0] DP_PASS1   = 4'd2;
    localparam [3:0] DP_PASS2   = 4'd3;
    localparam [3:0] CALC       = 4'd4;
    localparam [3:0] DONE_STATE = 4'd5;

    reg [3:0] state, next_state;
    
    // Internal registers
    reg [15:0] total_bags;
    reg [31:0] total_price;
    reg [3:0] farmer_idx;
    
    // DP arrays - indexed by bag count (0-511)
    reg [15:0] dp1 [0:511]; // Store 1: min price for given bag count
    reg [15:0] dp2 [0:511]; // Store 2: min price for given bag count
    
    // DP state variables
    reg [8:0] dp_idx;
    reg [7:0] bags;
    reg [15:0] price;
    reg [8:0] new_bags;
    reg [31:0] new_price;
    
    // Calculation variables
    reg [31:0] price1, price2;
    reg [15:0] bags1, bags2;
    reg [31:0] prod1, prod2;
    reg [63:0] product;
    reg [31:0] min_product;
    reg [2:0] calc_state;
    reg [8:0] search_idx;
    
    // Cycle counter for timeout
    reg [13:0] cycle_count;
    localparam [13:0] MAX_CYCLES = 14'd10000;
    
    // Reset and state transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 32'd0;
            total_bags <= 16'd0;
            total_price <= 32'd0;
            farmer_idx <= 4'd0;
            dp_idx <= 9'd0;
            bags <= 8'd0;
            price <= 16'd0;
            new_bags <= 9'd0;
            new_price <= 32'd0;
            price1 <= 32'd0;
            price2 <= 32'd0;
            bags1 <= 16'd0;
            bags2 <= 16'd0;
            prod1 <= 32'd0;
            prod2 <= 32'd0;
            product <= 64'd0;
            min_product <= 32'hFFFFFFFF;
            calc_state <= 3'd0;
            search_idx <= 9'd0;
            cycle_count <= 14'd0;
            // Initialize DP arrays
            for (dp_idx = 0; dp_idx < 512; dp_idx = dp_idx + 1) begin
                dp1[dp_idx] <= 16'hFFFF;
                dp2[dp_idx] <= 16'hFFFF;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    total_bags <= 16'd0;
                    total_price <= 32'd0;
                    farmer_idx <= 4'd0;
                    cycle_count <= 14'd0;
                    min_product <= 32'hFFFFFFFF;
                    // Initialize DP arrays
                    for (dp_idx = 0; dp_idx < 512; dp_idx = dp_idx + 1) begin
                        dp1[dp_idx] <= 16'hFFFF;
                        dp2[dp_idx] <= 16'hFFFF;
                    end
                    if (start) begin
                        state <= LOAD;
                    end
                end
                
                LOAD: begin
                    if (farmer_idx < N) begin
                        // Accumulate total bags and price
                        total_bags <= total_bags + a[farmer_idx];
                        total_price <= total_price + ({16'd0, c[farmer_idx]});
                        farmer_idx <= farmer_idx + 4'd1;
                    end else begin
                        // Initialize DP base cases
                        dp1[0] <= 16'd0;
                        dp2[0] <= 16'd0;
                        farmer_idx <= 4'd0;
                        dp_idx <= 9'd0;
                        state <= DP_PASS1;
                    end
                end
                
                DP_PASS1: begin
                    // Fill DP for store 1
                    if (farmer_idx < N) begin
                        bags <= a[farmer_idx];
                        price <= c[farmer_idx];
                        // Update DP from high to low to avoid reuse
                        for (dp_idx = 511; dp_idx >= a[farmer_idx]; dp_idx = dp_idx - 1) begin
                            if (dp1[dp_idx - a[farmer_idx]] != 16'hFFFF) begin
                                new_price = dp1[dp_idx - a[farmer_idx]] + c[farmer_idx];
                                if (new_price < dp1[dp_idx]) begin
                                    dp1[dp_idx] <= new_price[15:0];
                                end
                            end
                        end
                        farmer_idx <= farmer_idx + 4'd1;
                    end else begin
                        farmer_idx <= 4'd0;
                        dp_idx <= 9'd0;
                        state <= DP_PASS2;
                    end
                end
                
                DP_PASS2: begin
                    // Fill DP for store 2 (using total - store1)
                    if (farmer_idx < N) begin
                        bags <= a[farmer_idx];
                        price <= c[farmer_idx];
                        // Update DP from high to low
                        for (dp_idx = 511; dp_idx >= a[farmer_idx]; dp_idx = dp_idx - 1) begin
                            if (dp2[dp_idx - a[farmer_idx]] != 16'hFFFF) begin
                                new_price = dp2[dp_idx - a[farmer_idx]] + c[farmer_idx];
                                if (new_price < dp2[dp_idx]) begin
                                    dp2[dp_idx] <= new_price[15:0];
                                end
                            end
                        end
                        farmer_idx <= farmer_idx + 4'd1;
                    end else begin
                        farmer_idx <= 4'd0;
                        dp_idx <= L[8:0]; // Start search at L bags
                        search_idx <= L[8:0];
                        calc_state <= 3'd0;
                        state <= CALC;
                    end
                end
                
                CALC: begin
                    // Search for valid partitions where store1 has exactly L bags
                    case (calc_state)
                        3'd0: begin
                            // Check if store1 has valid solution at L bags
                            if (dp1[L[8:0]] != 16'hFFFF && L[8:0] <= total_bags) begin
                                bags1 <= L[8:0];
                                price1 <= {16'd0, dp1[L[8:0]]};
                                bags2 <= total_bags - L[8:0];
                                // Store2 price = total - store1
                                price2 <= total_price - {16'd0, dp1[L[8:0]]};
                                calc_state <= 3'd1;
                            end else begin
                                // Try next candidate for store1
                                search_idx <= search_idx + 9'd1;
                                if (search_idx > total_bags) begin
                                    calc_state <= 3'd2; // Switch to store2 focus
                                    search_idx <= L[8:0];
                                end
                            end
                        end
                        3'd1: begin
                            // Compute P1 = price1 * 65536 / bags1
                            prod1 <= (price1 * 32'd65536) / bags1;
                            // Compute P2 = price2 * 65536 / bags2  
                            prod2 <= (price2 * 32'd65536) / bags2;
                            calc_state <= 3'd2;
                        end
                        3'd2: begin
                            // Compute product = P1 * P2 >> 16
                            product <= ({32'd0, prod1} * {32'd0, prod2}) >> 16;
                            calc_state <= 3'd3;
                        end
                        3'd3: begin
                            // Update minimum
                            if (product[31:0] < min_product) begin
                                min_product <= product[31:0];
                            end
                            calc_state <= 3'd4;
                        end
                        3'd4: begin
                            // Check if we've exhausted store1 candidates
                            if (search_idx < total_bags) begin
                                search_idx <= search_idx + 9'd1;
                                calc_state <= 3'd0;
                            end else begin
                                // Now check store2 has exactly L bags
                                calc_state <= 3'd5;
                                search_idx <= L[8:0];
                            end
                        end
                        3'd5: begin
                            // Check if store2 has valid solution at L bags
                            if (dp2[L[8:0]] != 16'hFFFF && L[8:0] <= total_bags) begin
                                bags2 <= L[8:0];
                                price2 <= {16'd0, dp2[L[8:0]]};
                                bags1 <= total_bags - L[8:0];
                                // Store1 price = total - store2
                                price1 <= total_price - {16'd0, dp2[L[8:0]]};
                                calc_state <= 3'd6;
                            end else begin
                                // Try next candidate for store2
                                search_idx <= search_idx + 9'd1;
                                if (search_idx > total_bags) begin
                                    calc_state <= 3'd7; // Done
                                end
                            end
                        end
                        3'd6: begin
                            // Compute P1 = price1 * 65536 / bags1
                            prod1 <= (price1 * 32'd65536) / bags1;
                            // Compute P2 = price2 * 65536 / bags2
                            prod2 <= (price2 * 32'd65536) / bags2;
                            calc_state <= 3'd7;
                        end
                        3'd7: begin
                            // Compute product = P1 * P2 >> 16
                            product <= ({32'd0, prod1} * {32'd0, prod2}) >> 16;
                            calc_state <= 3'd8;
                        end
                        3'd8: begin
                            // Update minimum
                            if (product[31:0] < min_product) begin
                                min_product <= product[31:0];
                            end
                            // Continue searching store2 candidates
                            if (search_idx < total_bags) begin
                                search_idx <= search_idx + 9'd1;
                                calc_state <= 3'd5;
                            end else begin
                                calc_state <= 3'd9; // All done
                            end
                        end
                    endcase
                    
                    if (calc_state == 3'd9) begin
                        result <= min_product;
                        state <= DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            // Cycle count for timeout
            if (state != IDLE && state != DONE_STATE) begin
                cycle_count <= cycle_count + 14'd1;
                if (cycle_count >= MAX_CYCLES) begin
                    state <= DONE_STATE;
                    result <= 32'hFFFFFFFF; // Error indication
                end
            end
        end
    end

endmodule