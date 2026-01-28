module dinner_combinations(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire load_brands,
    input wire load_dish,
    input wire load_compat,
    input wire [7:0] data_in,
    input wire [7:0] addr,
    output reg [31:0] result,
    output reg done,
    output reg busy
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD_BRANDS = 3'd1;
    localparam [2:0] LOAD_DISHES = 3'd2;
    localparam [2:0] LOAD_COMPAT = 3'd3;
    localparam [2:0] COMPUTE = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    reg [2:0] state, next_state;

    // Counters and control
    reg [7:0] brand_count;
    reg [7:0] dish_count;
    reg [7:0] compat_count;
    reg [7:0] s_count, m_count, d_count;
    reg [7:0] s_idx, m_idx, d_idx;
    reg [7:0] ingredient_idx;
    reg [7:0] cycle_counter;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Brand counts (8-bit per ingredient, 256 max)
    reg [6:0] brand_counts [0:255];

    // Dish ingredient lists (max 20 ingredients per dish, 75 dishes)
    reg [7:0] dish_ingredients [0:74][0:19];
    reg [7:0] dish_sizes [0:74];

    // Incompatibility matrix (75x75, packed as bits)
    reg [74:0] incompat_matrix [0:74];

    // Temporary storage for computation
    reg [7:0] unique_ingredients [0:59];
    reg [5:0] unique_count;
    reg [31:0] product;
    reg [31:0] total_combinations;
    reg too_many;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            brand_count <= 8'd0;
            dish_count <= 8'd0;
            compat_count <= 8'd0;
            s_count <= 8'd0;
            m_count <= 8'd0;
            d_count <= 8'd0;
            s_idx <= 8'd0;
            m_idx <= 8'd0;
            d_idx <= 8'd0;
            ingredient_idx <= 8'd0;
            cycle_counter <= 8'd0;
            done <= 1'b0;
            busy <= 1'b0;
            result <= 32'd0;
            too_many <= 1'b0;
            total_combinations <= 32'd0;

            // Initialize arrays
            integer i, j;
            for (i = 0; i < 256; i = i + 1) begin
                brand_counts[i] <= 7'd0;
            end
            for (i = 0; i < 75; i = i + 1) begin
                dish_sizes[i] <= 8'd0;
                for (j = 0; j < 20; j = j + 1) begin
                    dish_ingredients[i][j] <= 8'd0;
                end
                incompat_matrix[i] <= 75'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    busy <= 1'b0;
                    done <= 1'b0;
                    if (start) begin
                        next_state <= LOAD_BRANDS;
                        busy <= 1'b1;
                        brand_count <= 8'd0;
                    end
                end

                LOAD_BRANDS: begin
                    if (load_brands) begin
                        brand_counts[addr] <= data_in[6:0];
                        brand_count <= brand_count + 8'd1;
                        if (brand_count == 8'd255) begin
                            next_state <= LOAD_DISHES;
                            dish_count <= 8'd0;
                        end
                    end
                end

                LOAD_DISHES: begin
                    if (load_dish) begin
                        if (dish_count < 8'd25) begin
                            s_count <= s_count + 8'd1;
                        end else if (dish_count < 8'd50) begin
                            m_count <= m_count + 8'd1;
                        end else if (dish_count < 8'd75) begin
                            d_count <= d_count + 8'd1;
                        end
                        dish_sizes[dish_count] <= data_in;
                        dish_count <= dish_count + 8'd1;
                        if (dish_count == 8'd75) begin
                            next_state <= LOAD_COMPAT;
                            compat_count <= 8'd0;
                        end
                    end
                end

                LOAD_COMPAT: begin
                    if (load_compat) begin
                        // addr = dish1, data_in = dish2
                        incompat_matrix[addr][data_in] <= 1'b1;
                        incompat_matrix[data_in][addr] <= 1'b1;
                        compat_count <= compat_count + 8'd1;
                        if (compat_count == 8'd2000) begin
                            next_state <= COMPUTE;
                            s_idx <= 8'd0;
                            m_idx <= 8'd0;
                            d_idx <= 8'd0;
                            cycle_counter <= 8'd0;
                            total_combinations <= 32'd0;
                            too_many <= 1'b0;
                        end
                    end
                end

                COMPUTE: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    if (cycle_counter >= MAX_CYCLES) begin
                        next_state <= DONE_STATE;
                        too_many <= 1'b1;
                    end else begin
                        // Check if current triple is valid
                        if (!incompat_matrix[s_idx][m_idx + s_count] &&
                            !incompat_matrix[s_idx][d_idx + s_count + m_count] &&
                            !incompat_matrix[m_idx + s_count][d_idx + s_count + m_count]) begin
                            // Compute unique ingredients
                            unique_count <= 6'd0;
                            integer i, j, k, l;
                            reg found;
                            // Add starter ingredients
                            for (i = 0; i < dish_sizes[s_idx]; i = i + 1) begin
                                found <= 1'b0;
                                for (j = 0; j < unique_count; j = j + 1) begin
                                    if (unique_ingredients[j] == dish_ingredients[s_idx][i]) begin
                                        found <= 1'b1;
                                    end
                                end
                                if (!found && unique_count < 6'd60) begin
                                    unique_ingredients[unique_count] <= dish_ingredients[s_idx][i];
                                    unique_count <= unique_count + 6'd1;
                                end
                            end
                            // Add main ingredients
                            for (i = 0; i < dish_sizes[m_idx + s_count]; i = i + 1) begin
                                found <= 1'b0;
                                for (j = 0; j < unique_count; j = j + 1) begin
                                    if (unique_ingredients[j] == dish_ingredients[m_idx + s_count][i]) begin
                                        found <= 1'b1;
                                    end
                                end
                                if (!found && unique_count < 6'd60) begin
                                    unique_ingredients[unique_count] <= dish_ingredients[m_idx + s_count][i];
                                    unique_count <= unique_count + 6'd1;
                                end
                            end
                            // Add dessert ingredients
                            for (i = 0; i < dish_sizes[d_idx + s_count + m_count]; i = i + 1) begin
                                found <= 1'b0;
                                for (j = 0; j < unique_count; j = j + 1) begin
                                    if (unique_ingredients[j] == dish_ingredients[d_idx + s_count + m_count][i]) begin
                                        found <= 1'b1;
                                    end
                                end
                                if (!found && unique_count < 6'd60) begin
                                    unique_ingredients[unique_count] <= dish_ingredients[d_idx + s_count + m_count][i];
                                    unique_count <= unique_count + 6'd1;
                                end
                            end
                            // Compute product
                            product <= 32'd1;
                            for (i = 0; i < unique_count; i = i + 1) begin
                                product <= product * brand_counts[unique_ingredients[i]];
                                if (product > 32'd2147483647) begin
                                    too_many <= 1'b1;
                                end
                            end
                            if (!too_many) begin
                                total_combinations <= total_combinations + product;
                                if (total_combinations > 32'd2147483647) begin
                                    too_many <= 1'b1;
                                end
                            end
                        end
                        // Increment counters
                        d_idx <= d_idx + 8'd1;
                        if (d_idx == d_count) begin
                            d_idx <= 8'd0;
                            m_idx <= m_idx + 8'd1;
                            if (m_idx == m_count) begin
                                m_idx <= 8'd0;
                                s_idx <= s_idx + 8'd1;
                                if (s_idx == s_count) begin
                                    next_state <= DONE_STATE;
                                end
                            end
                        end
                    end
                end

                DONE_STATE: begin
                    if (too_many) begin
                        result <= 32'hFFFFFFFF;
                    end else begin
                        result <= total_combinations;
                    end
                    done <= 1'b1;
                    busy <= 1'b0;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    busy <= 1'b0;
                end
            endcase
        end
    end

    // Load dish ingredients
    always @(posedge clk) begin
        if (state == LOAD_DISHES && load_dish) begin
            if (ingredient_idx < dish_sizes[dish_count]) begin
                dish_ingredients[dish_count][ingredient_idx] <= data_in;
                ingredient_idx <= ingredient_idx + 8'd1;
            end
        end
    end

endmodule