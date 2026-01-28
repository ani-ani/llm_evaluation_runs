module translator_matcher(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire config_mode,
    input wire [15:0] data_in,
    input wire data_valid,
    output reg done,
    output reg result_valid,
    output reg [15:0] match_out,
    output reg [1:0] status
);

    // Parameters
    localparam [7:0] M_MAX = 8'd200;
    localparam [7:0] N_MAX = 8'd100;
    localparam [7:0] DATA_WIDTH = 8'd8;
    localparam [7:0] EDGE_WIDTH = 8'd9;

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CONFIG = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] translator_count;
    reg [7:0] language_index;
    reg [7:0] current_translator;
    reg [7:0] current_language;
    reg [7:0] matching_count;
    reg [7:0] output_ptr;
    reg [7:0] dfs_stack_ptr;
    reg [7:0] dfs_current;
    reg [7:0] dfs_target;
    reg [7:0] visited_ptr;
    reg [7:0] path_ptr;
    reg [7:0] temp_u;
    reg [7:0] temp_v;
    reg [7:0] temp_i;
    reg [7:0] temp_j;
    reg [7:0] temp_k;
    reg [7:0] temp_l;
    reg [7:0] temp_m;
    reg [7:0] temp_n;
    reg [7:0] temp_o;
    reg [7:0] temp_p;
    reg [7:0] temp_q;
    reg [7:0] temp_r;
    reg [7:0] temp_s;
    reg [7:0] temp_t;
    reg [7:0] temp_u2;
    reg [7:0] temp_v2;
    reg [7:0] temp_w;
    reg [7:0] temp_x;
    reg [7:0] temp_y;
    reg [7:0] temp_z;
    reg [7:0] temp_a;
    reg [7:0] temp_b;
    reg [7:0] temp_c;
    reg [7:0] temp_d;
    reg [7:0] temp_e;
    reg [7:0] temp_f;
    reg [7:0] temp_g;
    reg [7:0] temp_h;
    reg [7:0] temp_i2;
    reg [7:0] temp_j2;
    reg [7:0] temp_k2;
    reg [7:0] temp_l2;
    reg [7:0] temp_m2;
    reg [7:0] temp_n2;
    reg [7:0] temp_o2;
    reg [7:0] temp_p2;
    reg [7:0] temp_q2;
    reg [7:0] temp_r2;
    reg [7:0] temp_s2;
    reg [7:0] temp_t2;
    reg [7:0] temp_u3;
    reg [7:0] temp_v3;
    reg [7:0] temp_w2;
    reg [7:0] temp_x2;
    reg [7:0] temp_y2;
    reg [7:0] temp_z2;
    reg [7:0] temp_a2;
    reg [7:0] temp_b2;
    reg [7:0] temp_c2;
    reg [7:0] temp_d2;
    reg [7:0] temp_e2;
    reg [7:0] temp_f2;
    reg [7:0] temp_g2;
    reg [7:0] temp_h2;
    reg [7:0] temp_i3;
    reg [7:0] temp_j3;
    reg [7:0] temp_k3;
    reg [7:0] temp_l3;
    reg [7:0] temp_m3;
    reg [7:0] temp_n3;
    reg [7:0] temp_o3;
    reg [7:0] temp_p3;
    reg [7:0] temp_q3;
    reg [7:0] temp_r3;
    reg [7:0] temp_s3;
    reg [7:0] temp_t3;
    reg [7:0] temp_u4;
    reg [7:0] temp_v4;
    reg [7:0] temp_w3;
    reg [7:0] temp_x3;
    reg [7:0] temp_y3;
    reg [7:0] temp_z3;
    reg [7:0] temp_a3;
    reg [7:0] temp_b3;
    reg [7:0] temp_c3;
    reg [7:0] temp_d3;
    reg [7:0] temp_e3;
    reg [7:0] temp_f3;
    reg [7:0] temp_g3;
    reg [7:0] temp_h3;
    reg [7:0] temp_i4;
    reg [7:0] temp_j4;
    reg [7:0] temp_k4;
    reg [7:0] temp_l4;
    reg [7:0] temp_m4;
    reg [7:0] temp_n4;
    reg [7:0] temp_o4;
    reg [7:0] temp_p4;
    reg [7:0] temp_q4;
    reg [7:0] temp_r4;
    reg [7:0] temp_s4;
    reg [7:0] temp_t4;

    // Memory arrays
    reg [7:0] translator_languages [0:199];
    reg [7:0] translator_languages2 [0:199];
    reg [7:0] match [0:199];
    reg [7:0] visited [0:199];
    reg [7:0] path [0:199];
    reg [7:0] dfs_stack [0:199];
    reg [7:0] adj_matrix [0:199][0:199];

    // Initialize all registers
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            translator_count <= 8'd0;
            language_index <= 8'd0;
            current_translator <= 8'd0;
            current_language <= 8'd0;
            matching_count <= 8'd0;
            output_ptr <= 8'd0;
            dfs_stack_ptr <= 8'd0;
            dfs_current <= 8'd0;
            dfs_target <= 8'd0;
            visited_ptr <= 8'd0;
            path_ptr <= 8'd0;
            temp_u <= 8'd0;
            temp_v <= 8'd0;
            temp_i <= 8'd0;
            temp_j <= 8'd0;
            temp_k <= 8'd0;
            temp_l <= 8'd0;
            temp_m <= 8'd0;
            temp_n <= 8'd0;
            temp_o <= 8'd0;
            temp_p <= 8'd0;
            temp_q <= 8'd0;
            temp_r <= 8'd0;
            temp_s <= 8'd0;
            temp_t <= 8'd0;
            temp_u2 <= 8'd0;
            temp_v2 <= 8'd0;
            temp_w <= 8'd0;
            temp_x <= 8'd0;
            temp_y <= 8'd0;
            temp_z <= 8'd0;
            temp_a <= 8'd0;
            temp_b <= 8'd0;
            temp_c <= 8'd0;
            temp_d <= 8'd0;
            temp_e <= 8'd0;
            temp_f <= 8'd0;
            temp_g <= 8'd0;
            temp_h <= 8'd0;
            temp_i2 <= 8'd0;
            temp_j2 <= 8'd0;
            temp_k2 <= 8'd0;
            temp_l2 <= 8'd0;
            temp_m2 <= 8'd0;
            temp_n2 <= 8'd0;
            temp_o2 <= 8'd0;
            temp_p2 <= 8'd0;
            temp_q2 <= 8'd0;
            temp_r2 <= 8'd0;
            temp_s2 <= 8'd0;
            temp_t2 <= 8'd0;
            temp_u3 <= 8'd0;
            temp_v3 <= 8'd0;
            temp_w2 <= 8'd0;
            temp_x2 <= 8'd0;
            temp_y2 <= 8'd0;
            temp_z2 <= 8'd0;
            temp_a2 <= 8'd0;
            temp_b2 <= 8'd0;
            temp_c2 <= 8'd0;
            temp_d2 <= 8'd0;
            temp_e2 <= 8'd0;
            temp_f2 <= 8'd0;
            temp_g2 <= 8'd0;
            temp_h2 <= 8'd0;
            temp_i3 <= 8'd0;
            temp_j3 <= 8'd0;
            temp_k3 <= 8'd0;
            temp_l3 <= 8'd0;
            temp_m3 <= 8'd0;
            temp_n3 <= 8'd0;
            temp_o3 <= 8'd0;
            temp_p3 <= 8'd0;
            temp_q3 <= 8'd0;
            temp_r3 <= 8'd0;
            temp_s3 <= 8'd0;
            temp_t3 <= 8'd0;
            temp_u4 <= 8'd0;
            temp_v4 <= 8'd0;
            temp_w3 <= 8'd0;
            temp_x3 <= 8'd0;
            temp_y3 <= 8'd0;
            temp_z3 <= 8'd0;
            temp_a3 <= 8'd0;
            temp_b3 <= 8'd0;
            temp_c3 <= 8'd0;
            temp_d3 <= 8'd0;
            temp_e3 <= 8'd0;
            temp_f3 <= 8'd0;
            temp_g3 <= 8'd0;
            temp_h3 <= 8'd0;
            temp_i4 <= 8'd0;
            temp_j4 <= 8'd0;
            temp_k4 <= 8'd0;
            temp_l4 <= 8'd0;
            temp_m4 <= 8'd0;
            temp_n4 <= 8'd0;
            temp_o4 <= 8'd0;
            temp_p4 <= 8'd0;
            temp_q4 <= 8'd0;
            temp_r4 <= 8'd0;
            temp_s4 <= 8'd0;
            temp_t4 <= 8'd0;
            done <= 1'b0;
            result_valid <= 1'b0;
            match_out <= 16'd0;
            status <= 2'd0;
            for (i = 0; i < 200; i = i + 1) begin
                translator_languages[i] <= 8'd0;
                translator_languages2[i] <= 8'd0;
                match[i] <= 8'd255;
                visited[i] <= 8'd0;
                path[i] <= 8'd0;
                dfs_stack[i] <= 8'd0;
                for (temp_j = 0; temp_j < 200; temp_j = temp_j + 1) begin
                    adj_matrix[i][temp_j] <= 8'd0;
                end
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    if (config_mode == 1'b0 && data_valid) begin
                        next_state <= CONFIG;
                    end else if (config_mode == 1'b1 && start) begin
                        next_state <= COMPUTE;
                    end
                end
                CONFIG: begin
                    if (data_valid) begin
                        if (language_index == 8'd0) begin
                            translator_languages[current_translator] <= data_in[7:0];
                            language_index <= 8'd1;
                        end else begin
                            translator_languages2[current_translator] <= data_in[7:0];
                            language_index <= 8'd0;
                            current_translator <= current_translator + 8'd1;
                            if (current_translator == translator_count) begin
                                next_state <= IDLE;
                            end
                        end
                    end
                end
                COMPUTE: begin
                    if (matching_count * 2 == translator_count) begin
                        next_state <= OUTPUT;
                    end else begin
                        temp_u <= 8'd0;
                        for (temp_i = 0; temp_i < translator_count; temp_i = temp_i + 1) begin
                            if (match[temp_i] == 8'd255) begin
                                temp_u <= temp_i;
                                break;
                            end
                        end
                        if (temp_u < translator_count) begin
                            for (temp_j = 0; temp_j < translator_count; temp_j = temp_j + 1) begin
                                visited[temp_j] <= 8'd0;
                            end
                            dfs_stack_ptr <= 8'd0;
                            dfs_stack[0] <= temp_u;
                            visited[temp_u] <= 8'd1;
                            path[temp_u] <= 8'd255;
                            temp_v <= 8'd0;
                            for (temp_k = 0; temp_k < translator_count; temp_k = temp_k + 1) begin
                                if (adj_matrix[temp_u][temp_k] == 8'd1 && match[temp_k] == 8'd255) begin
                                    temp_v <= temp_k;
                                    break;
                                end
                            end
                            if (temp_v < translator_count) begin
                                match[temp_u] <= temp_v;
                                match[temp_v] <= temp_u;
                                matching_count <= matching_count + 8'd1;
                            end else begin
                                dfs_stack_ptr <= dfs_stack_ptr + 8'd1;
                                dfs_current <= dfs_stack[dfs_stack_ptr];
                                temp_l <= 8'd0;
                                for (temp_m = 0; temp_m < translator_count; temp_m = temp_m + 1) begin
                                    if (adj_matrix[dfs_current][temp_m] == 8'd1 && visited[temp_m] == 8'd0) begin
                                        temp_l <= temp_m;
                                        break;
                                    end
                                end
                                if (temp_l < translator_count) begin
                                    visited[temp_l] <= 8'd1;
                                    path[temp_l] <= dfs_current;
                                    if (match[temp_l] == 8'd255) begin
                                        temp_n <= temp_l;
                                        while (path[temp_n] != 8'd255) begin
                                            temp_o <= path[temp_n];
                                            temp_p <= match[temp_o];
                                            match[temp_n] <= temp_o;
                                            match[temp_o] <= temp_n;
                                            temp_n <= temp_p;
                                        end
                                        matching_count <= matching_count + 8'd1;
                                    end else begin
                                        dfs_stack[dfs_stack_ptr] <= match[temp_l];
                                        dfs_stack_ptr <= dfs_stack_ptr + 8'd1;
                                    end
                                end else begin
                                    dfs_stack_ptr <= dfs_stack_ptr - 8'd1;
                                end
                            end
                        end else begin
                            next_state <= OUTPUT;
                        end
                    end
                end
                OUTPUT: begin
                    if (output_ptr < translator_count) begin
                        if (match[output_ptr] != 8'd255) begin
                            match_out <= {match[output_ptr], output_ptr};
                            result_valid <= 1'b1;
                            output_ptr <= output_ptr + 8'd2;
                        end else begin
                            output_ptr <= output_ptr + 8'd1;
                        end
                    end else begin
                        done <= 1'b1;
                        next_state <= DONE_STATE;
                    end
                end
                DONE_STATE: begin
                    done <= 1'b0;
                    next_state <= IDLE;
                end
                default: next_state <= IDLE;
            endcase
        end
    end

    // Build adjacency matrix
    always @(posedge clk) begin
        if (state == COMPUTE && translator_count > 8'd0) begin
            for (temp_q = 0; temp_q < translator_count; temp_q = temp_q + 1) begin
                for (temp_r = temp_q + 8'd1; temp_r < translator_count; temp_r = temp_r + 1) begin
                    if (translator_languages[temp_q] == translator_languages[temp_r] ||
                        translator_languages[temp_q] == translator_languages2[temp_r] ||
                        translator_languages2[temp_q] == translator_languages[temp_r] ||
                        translator_languages2[temp_q] == translator_languages2[temp_r]) begin
                        adj_matrix[temp_q][temp_r] <= 8'd1;
                        adj_matrix[temp_r][temp_q] <= 8'd1;
                    end else begin
                        adj_matrix[temp_q][temp_r] <= 8'd0;
                        adj_matrix[temp_r][temp_q] <= 8'd0;
                    end
                end
            end
        end
    end

    // Status update
    always @(posedge clk) begin
        case (state)
            IDLE: status <= 2'd0;
            CONFIG: status <= 2'd0;
            COMPUTE: status <= 2'd1;
            OUTPUT: begin
                if (matching_count * 2 == translator_count) begin
                    status <= 2'd2;
                end else begin
                    status <= 2'd3;
                end
            end
            DONE_STATE: status <= 2'd0;
            default: status <= 2'd0;
        endcase
    end

endmodule