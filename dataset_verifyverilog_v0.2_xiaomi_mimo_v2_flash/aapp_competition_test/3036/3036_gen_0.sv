module chef_dinner_counter(
    input clk,
    input rst_n,
    input start,
    input [5:0] r_num,
    input [3:0] s_num, m_num, d_num,
    input [3:0] n_num,
    input [6:0] brands [0:15],
    input [7:0] dish_ing_count [0:23],
    input [3:0] dish_ingredients [0:191],
    input [5:0] incompat_dish1 [0:15],
    input [5:0] incompat_dish2 [0:15],
    output reg [31:0] result,
    output reg done,
    output reg too_many_flag
);

    // States
    localparam IDLE = 3'b000;
    localparam PREP_OFFSETS = 3'b001;
    localparam CHECK_COMPAT = 3'b010;
    localparam CALC_PRODUCT = 3'b011;
    localparam SUM_UP = 3'b100;
    localparam DONE = 3'b101;

    reg [2:0] state, next_state;

    // Iterators and Registers
    reg [3:0] i, j, k; // Course local indices
    reg [3:0] next_i, next_j, next_k;
    
    reg [31:0] current_sum;
    reg [31:0] next_sum;
    reg [31:0] current_product;
    reg [31:0] next_product;
    
    // Offset Calculation
    reg [4:0] prep_cnt; // 0-24
    reg [7:0] offsets [0:24]; // Prefix sums
    
    // Control Flags
    reg triplet_invalid;
    
    // Constants
    localparam [31:0] LIMIT = 32'd1000000;

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 0;
            j <= 0;
            k <= 0;
            current_sum <= 0;
            current_product <= 0;
            prep_cnt <= 0;
        end else begin
            state <= next_state;
            i <= next_i;
            j <= next_j;
            k <= next_k;
            current_sum <= next_sum;
            current_product <= next_product;
            
            // Offset calculation update
            if (state == PREP_OFFSETS) begin
                prep_cnt <= prep_cnt + 1;
                if (prep_cnt < 24) begin
                    if (prep_cnt == 0) offsets[0] <= 0;
                    else offsets[prep_cnt] <= offsets[prep_cnt - 1] + dish_ing_count[prep_cnt - 1];
                end
            end else if (state == IDLE) begin
                prep_cnt <= 0;
            end
        end
    end

    // Combinational Logic
    always @(*) begin
        // Defaults
        next_state = state;
        next_i = i;
        next_j = j;
        next_k = k;
        next_sum = current_sum;
        next_product = current_product;
        done = 1'b0;
        too_many_flag = 1'b0;
        result = current_sum;
        triplet_invalid = 1'b0;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PREP_OFFSETS;
                    next_sum = 0;
                    next_product = 0;
                end
            end

            PREP_OFFSETS: begin
                // Calculate final offset for dish 23 and 24
                if (prep_cnt == 24) begin
                    // Offset for dish 24 (end of array)
                    // This is calculated in the seq logic at prep_cnt=24 step?
                    // Let's do it here just in case, though seq logic handles it for prep_cnt=23 -> 24.
                    // We just wait for prep_cnt to finish cycle.
                    next_state = CHECK_COMPAT;
                    next_i = 0;
                    next_j = 0;
                    next_k = 0;
                end else if (prep_cnt == 0) begin
                     // Ensure offset[0] is 0 (handled in seq logic, but ensure transition)
                     if (offsets[0] != 0) offsets[0] = 0; // Fallback assignment
                     next_state = PREP_OFFSETS;
                end else begin
                     next_state = PREP_OFFSETS;
                end
            end

            CHECK_COMPAT: begin
                // Check Incompatibilities (Parallel check)
                reg incompatible;
                integer p;
                reg [5:0] g_i, g_j, g_k;
                g_i = i;
                g_j = s_num + j;
                g_k = s_num + m_num + k;
                
                incompatible = 1'b0;
                for (p = 0; p < 16; p = p + 1) begin
                    if (p < n_num) begin
                        if ((incompat_dish1[p] == g_i && incompat_dish2[p] == g_j) ||
                            (incompat_dish1[p] == g_j && incompat_dish2[p] == g_i) ||
                            (incompat_dish1[p] == g_i && incompat_dish2[p] == g_k) ||
                            (incompat_dish1[p] == g_k && incompat_dish2[p] == g_i) ||
                            (incompat_dish1[p] == g_j && incompat_dish2[p] == g_k) ||
                            (incompat_dish1[p] == g_k && incompat_dish2[p] == g_j)) 
                            incompatible = 1'b1;
                    end
                end
                
                triplet_invalid = incompatible;
                next_state = CALC_PRODUCT;
            end

            CALC_PRODUCT: begin
                if (triplet_invalid) begin
                    next_product = 0;
                end else begin
                    // Build Union Mask
                    reg [15:0] u_mask;
                    reg [3:0] ing;
                    integer d_idx;
                    integer off, cnt;
                    integer n;
                    reg [63:0] prod;
                    
                    u_mask = 0;
                    
                    // Process Starter (i)
                    off = offsets[i]; cnt = dish_ing_count[i];
                    for(n=0; n<8; n=n+1) if(n < cnt) begin ing = dish_ingredients[off+n]; u_mask[ing] = 1; end
                    
                    // Process Main (j) - Global index = s_num + j
                    d_idx = s_num + j;
                    off = offsets[d_idx]; cnt = dish_ing_count[d_idx];
                    for(n=0; n<8; n=n+1) if(n < cnt) begin ing = dish_ingredients[off+n]; u_mask[ing] = 1; end
                    
                    // Process Dessert (k) - Global index = s_num + m_num + k
                    d_idx = s_num + m_num + k;
                    off = offsets[d_idx]; cnt = dish_ing_count[d_idx];
                    for(n=0; n<8; n=n+1) if(n < cnt) begin ing = dish_ingredients[off+n]; u_mask[ing] = 1; end
                    
                    // Multiply Brands
                    prod = 1;
                    for(n=0; n<16; n=n+1) begin
                        if (u_mask[n]) prod = prod * brands[n];
                    end
                    
                    // Check Limit
                    if (prod > LIMIT) next_product = LIMIT + 1; // Overflow marker
                    else next_product = prod[31:0];
                end
                
                next_state = SUM_UP;
            end

            SUM_UP: begin
                // Add to sum
                if (current_product > LIMIT || current_sum + current_product > LIMIT) begin
                    next_sum = LIMIT + 1;
                end else begin
                    next_sum = current_sum + current_product;
                end
                
                // Increment Iterators
                if (k < d_num - 1) begin
                    next_k = k + 1;
                    next_j = j;
                    next_i = i;
                    next_state = CHECK_COMPAT;
                end else begin
                    next_k = 0;
                    if (j < m_num - 1) begin
                        next_j = j + 1;
                        next_i = i;
                        next_state = CHECK_COMPAT;
                    end else begin
                        next_j = 0;
                        if (i < s_num - 1) begin
                            next_i = i + 1;
                            next_state = CHECK_COMPAT;
                        end else begin
                            next_state = DONE;
                        end
                    end
                end
            end

            DONE: begin
                done = 1'b1;
                if (current_sum > LIMIT) begin
                    result = 0;
                    too_many_flag = 1'b1;
                end else begin
                    result = current_sum;
                    too_many_flag = 1'b0;
                end
                // Stay in DONE
                next_state = DONE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule