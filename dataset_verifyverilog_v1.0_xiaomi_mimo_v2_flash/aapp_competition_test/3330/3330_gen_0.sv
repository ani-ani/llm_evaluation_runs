module potato_optimizer (
    input clk,
    input rst_n,
    input start,
    input [3:0] N,          // Number of farmers (2-8)
    input [3:0] L,          // Required bags in one store (1-7)
    input [7:0] a [0:7],    // Potatoes per bag (1-100)
    input [19:0] c [0:7],   // Cost per bag (1-1000000)
    output reg [31:0] result, // Fixed-point 16.16 product P1*P2
    output reg done
);

// Parameters
localparam MAX_BAGS = 8;
localparam MAX_POTATOES = 8'd200;  // N*a[i] <= 8*100 = 800, but we cap at 200 for DP size
localparam IDLE = 3'd0;
localparam COMPUTE = 3'd1;
localparam CALCULATE = 3'd2;
localparam DONE = 3'd3;

reg [2:0] state;
reg [7:0] cycle_count;
localparam MAX_CYCLES = 8'd200;

// Internal signals
reg [7:0] total_potatoes;
reg [19:0] total_cost;
reg [3:0] current_bag;

// DP arrays: [bags][potatoes]
reg [19:0] dp_cost [0:MAX_BAGS][0:MAX_POTATOES];
reg dp_valid [0:MAX_BAGS][0:MAX_POTATOES];

// Result calculation
reg [31:0] best_product;
reg [3:0] check_k;
reg [7:0] check_t;
reg [2:0] calc_state;
localparam CALC_INIT = 3'd0;
localparam CALC_CHECK = 3'd1;
localparam CALC_UPDATE = 3'd2;
localparam CALC_NEXT = 3'd3;

// Intermediate calculation registers
reg [39:0] numerator;
reg [39:0] denominator;
reg [31:0] product;

integer i, j;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 0;
        result <= 0;
        cycle_count <= 0;
        total_potatoes <= 0;
        total_cost <= 0;
        current_bag <= 0;
        best_product <= 32'h7FFFFFFF;
        check_k <= 0;
        check_t <= 0;
        calc_state <= CALC_INIT;
        numerator <= 0;
        denominator <= 0;
        product <= 0;
        
        // Clear DP arrays
        for (i = 0; i <= MAX_BAGS; i = i + 1) begin
            for (j = 0; j <= MAX_POTATOES; j = j + 1) begin
                dp_cost[i][j] <= 20'd0;
                dp_valid[i][j] <= 0;
            end
        end
    end else begin
        case (state)
            IDLE: begin
                done <= 0;
                cycle_count <= 0;
                if (start) begin
                    // Compute totals
                    total_potatoes <= 0;
                    total_cost <= 0;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (i < N) begin
                            total_potatoes <= total_potatoes + a[i];
                            total_cost <= total_cost + c[i];
                        end
                    end
                    
                    // Initialize DP
                    for (i = 0; i <= MAX_BAGS; i = i + 1) begin
                        for (j = 0; j <= MAX_POTATOES; j = j + 1) begin
                            dp_valid[i][j] <= 0;
                        end
                    end
                    dp_cost[0][0] <= 0;
                    dp_valid[0][0] <= 1;
                    
                    current_bag <= 0;
                    state <= COMPUTE;
                end
            end
            
            COMPUTE: begin
                cycle_count <= cycle_count + 1;
                if (current_bag < N) begin
                    // Process one bag using 0/1 knapsack DP
                    // Update DP in reverse to avoid using same bag twice
                    for (i = MAX_BAGS; i >= 1; i = i - 1) begin
                        for (j = MAX_POTATOES; j >= a[current_bag]; j = j - 1) begin
                            if (dp_valid[i-1][j - a[current_bag]]) begin
                                if (!dp_valid[i][j] || (dp_cost[i-1][j - a[current_bag]] + c[current_bag] < dp_cost[i][j])) begin
                                    dp_cost[i][j] <= dp_cost[i-1][j - a[current_bag]] + c[current_bag];
                                    dp_valid[i][j] <= 1;
                                end
                            end
                        end
                    end
                    current_bag <= current_bag + 1;
                end else if (cycle_count >= MAX_CYCLES) begin
                    state <= DONE;
                end else begin
                    // Done processing all bags
                    check_k <= 0;
                    check_t <= 0;
                    best_product <= 32'h7FFFFFFF;
                    calc_state <= CALC_INIT;
                    state <= CALCULATE;
                end
            end
            
            CALCULATE: begin
                cycle_count <= cycle_count + 1;
                
                case (calc_state)
                    CALC_INIT: begin
                        check_k <= 0;
                        calc_state <= CALC_CHECK;
                    end
                    
                    CALC_CHECK: begin
                        if (check_k <= N) begin
                            // Check case where store 1 has exactly L bags
                            if (check_k == L) begin
                                for (check_t = 0; check_t <= MAX_POTATOES; check_t = check_t + 1) begin
                                    if (dp_valid[check_k][check_t] && dp_valid[N - check_k][total_potatoes - check_t]) begin
                                        if (check_t > 0 && (total_potatoes - check_t) > 0) begin
                                            // Calculate product: (cost1/cost2) / (pot1/pot2) = (cost1*cost2*2^16)/(pot1*pot2)
                                            if (dp_cost[check_k][check_t] > 0 && (total_cost - dp_cost[check_k][check_t]) > 0) begin
                                                numerator <= dp_cost[check_k][check_t] * (total_cost - dp_cost[check_k][check_t]);
                                                denominator <= check_t * (total_potatoes - check_t);
                                                calc_state <= CALC_UPDATE;
                                            end
                                        end
                                    end
                                end
                                if (calc_state != CALC_UPDATE) begin
                                    calc_state <= CALC_NEXT;
                                end
                            end else if (check_k == (N - L) && L != (N - L)) begin
                                // Check case where store 2 has exactly L bags (store 1 has N-L bags)
                                for (check_t = 0; check_t <= MAX_POTATOES; check_t = check_t + 1) begin
                                    if (dp_valid[check_k][check_t] && dp_valid[N - check_k][total_potatoes - check_t]) begin
                                        if (check_t > 0 && (total_potatoes - check_t) > 0) begin
                                            if (dp_cost[check_k][check_t] > 0 && (total_cost - dp_cost[check_k][check_t]) > 0) begin
                                                numerator <= dp_cost[check_k][check_t] * (total_cost - dp_cost[check_k][check_t]);
                                                denominator <= check_t * (total_potatoes - check_t);
                                                calc_state <= CALC_UPDATE;
                                            end
                                        end
                                    end
                                end
                                if (calc_state != CALC_UPDATE) begin
                                    calc_state <= CALC_NEXT;
                                end
                            end else begin
                                calc_state <= CALC_NEXT;
                            end
                        end else begin
                            // Done checking all k
                            result <= best_product;
                            done <= 1;
                            state <= DONE;
                        end
                    end
                    
                    CALC_UPDATE: begin
                        if (denominator != 0) begin
                            // Scale numerator by 2^16 (left shift 16 bits)
                            numerator <= numerator << 16;
                            // After one cycle, compute division
                            product <= numerator / denominator;
                            if ((numerator / denominator) < best_product) begin
                                best_product <= (numerator / denominator);
                            end
                        end
                        calc_state <= CALC_NEXT;
                    end
                    
                    CALC_NEXT: begin
                        check_k <= check_k + 1;
                        calc_state <= CALC_CHECK;
                    end
                    
                    default: calc_state <= CALC_INIT;
                endcase
                
                if (cycle_count >= MAX_CYCLES) begin
                    state <= DONE;
                end
            end
            
            DONE: begin
                done <= 0;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule