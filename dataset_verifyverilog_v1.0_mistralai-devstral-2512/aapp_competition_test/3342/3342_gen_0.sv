module OnionThief(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire config_valid,
    input wire signed [15:0] onion_x,
    input wire signed [15:0] onion_y,
    input wire signed [15:0] post_x,
    input wire signed [15:0] post_y,
    output reg signed [15:0] result,
    output reg done
);

    // Constants
    localparam [3:0] MAX_ONIONS = 4'd16;
    localparam [3:0] MAX_POSTS = 4'd16;
    localparam [3:0] MAX_K = 4'd16;
    localparam [15:0] MAX_CYCLES = 16'd1024;

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] ITERATE_SUBSETS = 3'd2;
    localparam [2:0] CHECK_POINT = 3'd3;
    localparam [2:0] UPDATE_MAX = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [15:0] cycle_count;
    reg [3:0] onion_count;
    reg [3:0] post_count;
    reg [3:0] k_value;
    reg [3:0] current_onion;
    reg [3:0] current_post;
    reg [15:0] max_onions;
    reg [15:0] current_onions_inside;
    reg [15:0] subset_mask;
    reg [3:0] subset_size;
    reg [3:0] subset_index;
    reg [3:0] edge_index;
    reg signed [31:0] cross_product;
    reg inside_flag;

    // Storage for onions and posts
    reg signed [15:0] onions_x [0:15];
    reg signed [15:0] onions_y [0:15];
    reg signed [15:0] posts_x [0:15];
    reg signed [15:0] posts_y [0:15];

    // Temporary storage for selected posts
    reg signed [15:0] selected_x [0:15];
    reg signed [15:0] selected_y [0:15];
    reg [3:0] selected_count;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 16'd0;
            onion_count <= 4'd0;
            post_count <= 4'd0;
            k_value <= 4'd0;
            current_onion <= 4'd0;
            current_post <= 4'd0;
            max_onions <= 16'd0;
            current_onions_inside <= 16'd0;
            subset_mask <= 16'd0;
            subset_size <= 4'd0;
            subset_index <= 4'd0;
            edge_index <= 4'd0;
            cross_product <= 32'd0;
            inside_flag <= 1'b0;
            selected_count <= 4'd0;

            // Initialize arrays
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                onions_x[i] <= 16'd0;
                onions_y[i] <= 16'd0;
                posts_x[i] <= 16'd0;
                posts_y[i] <= 16'd0;
                selected_x[i] <= 16'd0;
                selected_y[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end
            end

            LOAD: begin
                if (config_valid && onion_count == MAX_ONIONS - 1 && post_count == MAX_POSTS - 1) begin
                    next_state = ITERATE_SUBSETS;
                end
            end

            ITERATE_SUBSETS: begin
                if (subset_mask == (1 << MAX_POSTS) - 1) begin
                    next_state = FINISH;
                end else if (subset_size == k_value) begin
                    next_state = CHECK_POINT;
                end
            end

            CHECK_POINT: begin
                if (current_onion == MAX_ONIONS - 1) begin
                    next_state = UPDATE_MAX;
                end
            end

            UPDATE_MAX: begin
                next_state = ITERATE_SUBSETS;
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Load onions and posts
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already initialized
        end else if (state == LOAD && config_valid) begin
            if (onion_count < MAX_ONIONS) begin
                onions_x[onion_count] <= onion_x;
                onions_y[onion_count] <= onion_y;
                onion_count <= onion_count + 1;
            end else if (post_count < MAX_POSTS) begin
                posts_x[post_count] <= post_x;
                posts_y[post_count] <= post_y;
                post_count <= post_count + 1;
            end
        end
    end

    // Iterate subsets
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already initialized
        end else if (state == ITERATE_SUBSETS) begin
            if (subset_mask == (1 << MAX_POSTS) - 1) begin
                subset_mask <= 16'd0;
            end else begin
                subset_mask <= subset_mask + 1;
            end

            // Count bits in subset_mask
            subset_size = 0;
            integer i;
            for (i = 0; i < MAX_POSTS; i = i + 1) begin
                if (subset_mask[i]) begin
                    subset_size = subset_size + 1;
                end
            end

            // Store selected posts
            selected_count = 0;
            for (i = 0; i < MAX_POSTS; i = i + 1) begin
                if (subset_mask[i]) begin
                    selected_x[selected_count] = posts_x[i];
                    selected_y[selected_count] = posts_y[i];
                    selected_count = selected_count + 1;
                end
            end

            current_onions_inside = 0;
            current_onion = 0;
        end
    end

    // Check if onion is inside convex hull
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already initialized
        end else if (state == CHECK_POINT) begin
            inside_flag = 1'b1;
            edge_index = 0;

            // Check against all edges
            for (edge_index = 0; edge_index < selected_count; edge_index = edge_index + 1) begin
                // Compute cross product
                cross_product = (selected_x[(edge_index + 1) % selected_count] - selected_x[edge_index]) * 
                               (onions_y[current_onion] - selected_y[edge_index]) - 
                               (selected_y[(edge_index + 1) % selected_count] - selected_y[edge_index]) * 
                               (onions_x[current_onion] - selected_x[edge_index]);

                // If cross product <= 0, point is not strictly inside
                if (cross_product <= 0) begin
                    inside_flag = 1'b0;
                end
            end

            if (inside_flag) begin
                current_onions_inside = current_onions_inside + 1;
            end

            if (current_onion < MAX_ONIONS - 1) begin
                current_onion = current_onion + 1;
            end
        end
    end

    // Update maximum onions
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already initialized
        end else if (state == UPDATE_MAX) begin
            if (current_onions_inside > max_onions) begin
                max_onions = current_onions_inside;
            end
        end
    end

    // Finish state
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already initialized
        end else if (state == FINISH) begin
            result <= max_onions;
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

    // Cycle counter to prevent infinite loops
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 16'd0;
        end else if (state != IDLE && state != FINISH) begin
            if (cycle_count < MAX_CYCLES - 1) begin
                cycle_count <= cycle_count + 1;
            end else begin
                cycle_count <= 16'd0;
                next_state = FINISH;
            end
        end
    end

endmodule