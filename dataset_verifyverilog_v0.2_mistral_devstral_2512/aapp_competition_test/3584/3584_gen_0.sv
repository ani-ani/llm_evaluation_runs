module convex_hull_protection(
    input clk,
    input rst_n,
    input start,
    input [15:0] onion_x,
    input [15:0] onion_y,
    input [15:0] post_x,
    input [15:0] post_y,
    input [2:0] post_index,
    input [2:0] num_posts,
    input [2:0] k_posts,
    input [2:0] num_onions,
    output reg [7:0] max_onions,
    output reg done,
    output reg error
);

parameter MAX_POSTS = 8;
parameter MAX_ONIONS = 8;
parameter MAX_K = 5;
parameter Q_SHIFT = 8;

parameter IDLE = 3'b000;
parameter LOAD_POSTS = 3'b001;
parameter LOAD_ONIONS = 3'b010;
parameter COMPUTE_COMBOS = 3'b011;
parameter CHECK_HULL = 3'b100;
parameter UPDATE_MAX = 3'b101;
parameter DONE_STATE = 3'b110;

reg [2:0] state, next_state;

reg signed [15:0] posts_x [0:MAX_POSTS-1];
reg signed [15:0] posts_y [0:MAX_POSTS-1];
reg signed [15:0] onions_x [0:MAX_ONIONS-1];
reg signed [15:0] onions_y [0:MAX_ONIONS-1];

reg [2:0] load_idx;
reg [2:0] onion_idx;
reg [2:0] combo_idx;
reg [2:0] check_idx;
reg [2:0] hull_idx;

reg [MAX_POSTS-1:0] selected_mask;
reg [2:0] selected_count;
reg [2:0] current_onion;

reg signed [31:0] cross_product;
reg signed [15:0] vec1_x, vec1_y, vec2_x, vec2_y;
reg inside_hull;
reg [7:0] onions_in_hull;
reg [7:0] best_result;

function signed [31:0] cross_product;
    input signed [15:0] v1x, v1y, v2x, v2y;
    begin
        cross_product = (v1x * v2y) - (v1y * v2x);
    end
endfunction

function is_inside_convex;
    input signed [15:0] px, py;
    input [2:0] num_vertices;
    reg signed [31:0] cp;
    reg sign_check;
    integer i, j;
    begin
        is_inside_convex = 1'b1;
        sign_check = 1'b0;
        for (i = 0; i < num_vertices; i = i + 1) begin
            j = (i + 1) % num_vertices;
            vec1_x = posts_x[j] - posts_x[i];
            vec2_x = px - posts_x[i];
            vec1_y = posts_y[j] - posts_y[i];
            vec2_y = py - posts_y[i];
            cp = cross_product(vec1_x, vec1_y, vec2_x, vec2_y);
            if (cp > 0) begin
                is_inside_convex = 1'b0;
                break;
            end
        end
    end
endfunction

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        error <= 1'b0;
        max_onions <= 8'b0;
        load_idx <= 3'b0;
        onion_idx <= 3'b0;
        combo_idx <= 3'b0;
        check_idx <= 3'b0;
        hull_idx <= 3'b0;
        selected_mask <= {MAX_POSTS{1'b0}};
        selected_count <= 3'b0;
        current_onion <= 3'b0;
        onions_in_hull <= 8'b0;
        best_result <= 8'b0;
        inside_hull <= 1'b0;
    end else begin
        state <= next_state;
    end
end

always @(*) begin
    next_state = state;
    case (state)
        IDLE: begin
            if (start) next_state = LOAD_POSTS;
        end
        LOAD_POSTS: begin
            if (load_idx >= num_posts) next_state = LOAD_ONIONS;
        end
        LOAD_ONIONS: begin
            if (onion_idx >= num_onions) next_state = COMPUTE_COMBOS;
        end
        COMPUTE_COMBOS: begin
            next_state = CHECK_HULL;
        end
        CHECK_HULL: begin
            if (current_onion >= num_onions) next_state = UPDATE_MAX;
            else next_state = CHECK_HULL;
        end
        UPDATE_MAX: begin
            if (combo_idx >= num_posts) next_state = DONE_STATE;
            else next_state = COMPUTE_COMBOS;
        end
        DONE_STATE: begin
            next_state = DONE_STATE;
        end
        default: next_state = IDLE;
    endcase
end

always @(posedge clk) begin
    if (state == LOAD_POSTS && start) begin
        posts_x[load_idx] <= post_x;
        posts_y[load_idx] <= post_y;
        load_idx <= load_idx + 1'b1;
    end
    if (state == LOAD_ONIONS && start) begin
        onions_x[onion_idx] <= onion_x;
        onions_y[onion_idx] <= onion_y;
        onion_idx <= onion_idx + 1'b1;
    end
    if (state == COMPUTE_COMBOS) begin
        combo_idx <= combo_idx + 1'b1;
        selected_count <= k_posts;
        if (combo_idx == 0) selected_mask <= 3'b111;
        else if (combo_idx == 1) selected_mask <= 5'b11010;
        else if (combo_idx == 2) selected_mask <= 6'b101001;
        else if (combo_idx == 3) selected_mask <= 7'b1001001;
        else if (combo_idx == 4) selected_mask <= 8'b10001001;
    end
    if (state == CHECK_HULL) begin
        if (selected_count >= 3) begin
            inside_hull = 1'b1;
            if (selected_mask[0] && selected_mask[1] && selected_mask[2]) begin
                vec1_x = posts_x[1] - posts_x[0];
                vec2_x = onions_x[current_onion] - posts_x[0];
                vec1_y = posts_y[1] - posts_y[0];
                vec2_y = onions_y[current_onion] - posts_y[0];
                cross_product = (vec1_x * vec2_y) - (vec1_y * vec2_x);
                if (cross_product > 0) inside_hull = 1'b0;
                vec1_x = posts_x[2] - posts_x[1];
                vec2_x = onions_x[current_onion] - posts_x[1];
                vec1_y = posts_y[2] - posts_y[1];
                vec2_y = onions_y[current_onion] - posts_y[1];
                cross_product = (vec1_x * vec2_y) - (vec1_y * vec2_x);
                if (cross_product > 0) inside_hull = 1'b0;
                vec1_x = posts_x[0] - posts_x[2];
                vec2_x = onions_x[current_onion] - posts_x[2];
                vec1_y = posts_y[0] - posts_y[2];
                vec2_y = onions_y[current_onion] - posts_y[2];
                cross_product = (vec1_x * vec2_y) - (vec1_y * vec2_x);
                if (cross_product > 0) inside_hull = 1'b0;
            end
            if (inside_hull) onions_in_hull <= onions_in_hull + 1'b1;
            current_onion <= current_onion + 1'b1;
        end else current_onion <= current_onion + 1'b1;
    end
    if (state == UPDATE_MAX) begin
        if (onions_in_hull > best_result) begin
            best_result <= onions_in_hull;
            max_onions <= onions_in_hull;
        end
        onions_in_hull <= 8'b0;
        current_onion <= 3'b0;
        combo_idx <= combo_idx + 1'b1;
    end
    if (state == DONE_STATE) done <= 1'b1;
end

endmodule

module data_loader(
    input clk,
    input rst_n,
    input load_en,
    input [15:0] data_x,
    input [15:0] data_y,
    input is_onion,
    output reg [2:0] index,
    output reg write_en
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        index <= 3'b0;
        write_en <= 1'b0;
    end else if (load_en) begin
        write_en <= 1'b1;
        index <= index + 1'b1;
    end else write_en <= 1'b0;
end

endmodule