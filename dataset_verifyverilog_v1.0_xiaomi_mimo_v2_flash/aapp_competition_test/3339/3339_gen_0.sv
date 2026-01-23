module evenland (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire edge_valid,
    input wire [3:0] N,
    input wire [4:0] M,
    input wire [2:0] edge_a,
    input wire [2:0] edge_b,
    output reg [31:0] result,
    output reg done
);

    localparam MAX_N = 8;
    localparam MAX_M = 16;
    localparam MOD = 32'd1000000009;

    localparam [3:0] IDLE           = 4'd0;
    localparam [3:0] COLLECT        = 4'd1;
    localparam [3:0] FIND_A         = 4'd2;
    localparam [3:0] FIND_B         = 4'd3;
    localparam [3:0] UNION          = 4'd4;
    localparam [3:0] CHECK_NEXT     = 4'd5;
    localparam [3:0] COUNT_INIT     = 4'd6;
    localparam [3:0] FIND_ROOT      = 4'd7;
    localparam [3:0] COUNT_INC      = 4'd8;
    localparam [3:0] CALC_RESULT    = 4'd9;
    localparam [3:0] SHIFT_LOOP     = 4'd10;
    localparam [3:0] FINISH         = 4'd11;

    reg [3:0] state;
    reg [4:0] edge_counter;
    reg [3:0] N_reg;
    reg [4:0] M_reg;
    reg [2:0] edge_a_reg;
    reg [2:0] edge_b_reg;
    reg [3:0] parent [0:MAX_N-1];
    reg [2:0] root_a;
    reg [2:0] root_b;
    reg [2:0] find_target;
    reg [2:0] current_vertex;
    reg [3:0] component_count;
    reg [3:0] i_loop;
    reg [31:0] pow2_val;
    reg [31:0] shift_count;
    reg [3:0] find_depth;
    reg find_done;
    reg [2:0] temp_root;
    reg [7:0] visited_mask;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            edge_counter <= 5'd0;
            N_reg <= 4'd0;
            M_reg <= 5'd0;
            edge_a_reg <= 3'd0;
            edge_b_reg <= 3'd0;
            root_a <= 3'd0;
            root_b <= 3'd0;
            find_target <= 3'd0;
            current_vertex <= 3'd0;
            component_count <= 4'd0;
            i_loop <= 4'd0;
            pow2_val <= 32'd1;
            shift_count <= 32'd0;
            find_depth <= 4'd0;
            find_done <= 1'b0;
            temp_root <= 3'd0;
            visited_mask <= 8'd0;
            parent[0] <= 4'd0;
            parent[1] <= 4'd1;
            parent[2] <= 4'd2;
            parent[3] <= 4'd3;
            parent[4] <= 4'd4;
            parent[5] <= 4'd5;
            parent[6] <= 4'd6;
            parent[7] <= 4'd7;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        N_reg <= N;
                        M_reg <= M;
                        edge_counter <= 5'd0;
                        parent[0] <= 4'd0;
                        parent[1] <= 4'd1;
                        parent[2] <= 4'd2;
                        parent[3] <= 4'd3;
                        parent[4] <= 4'd4;
                        parent[5] <= 4'd5;
                        parent[6] <= 4'd6;
                        parent[7] <= 4'd7;
                        state <= COLLECT;
                    end
                end

                COLLECT: begin
                    if (edge_counter >= M_reg) begin
                        state <= COUNT_INIT;
                    end else if (edge_valid) begin
                        edge_a_reg <= edge_a - 3'd1;
                        edge_b_reg <= edge_b - 3'd1;
                        find_target <= edge_a - 3'd1;
                        find_depth <= 4'd0;
                        state <= FIND_A;
                    end
                end

                FIND_A: begin
                    if (parent[find_target] == find_target) begin
                        root_a <= find_target;
                        find_target <= edge_b_reg;
                        find_depth <= 4'd0;
                        state <= FIND_B;
                    end else begin
                        find_target <= parent[find_target];
                        find_depth <= find_depth + 4'd1;
                        if (find_depth >= 4'd7) begin
                            root_a <= find_target;
                            find_target <= edge_b_reg;
                            find_depth <= 4'd0;
                            state <= FIND_B;
                        end
                    end
                end

                FIND_B: begin
                    if (parent[find_target] == find_target) begin
                        root_b <= find_target;
                        state <= UNION;
                    end else begin
                        find_target <= parent[find_target];
                        find_depth <= find_depth + 4'd1;
                        if (find_depth >= 4'd7) begin
                            root_b <= find_target;
                            state <= UNION;
                        end
                    end
                end

                UNION: begin
                    if (root_a != root_b) begin
                        parent[root_a] <= root_b;
                    end
                    edge_counter <= edge_counter + 5'd1;
                    state <= CHECK_NEXT;
                end

                CHECK_NEXT: begin
                    state <= COLLECT;
                end

                COUNT_INIT: begin
                    i_loop <= 4'd0;
                    component_count <= 4'd0;
                    visited_mask <= 8'd0;
                    state <= FIND_ROOT;
                end

                FIND_ROOT: begin
                    if (i_loop >= N_reg) begin
                        state <= CALC_RESULT;
                    end else begin
                        temp_root <= i_loop;
                        find_depth <= 4'd0;
                        find_done <= 1'b0;
                        state <= FIND_ROOT;
                        if (parent[i_loop] == i_loop) begin
                            if (!visited_mask[i_loop]) begin
                                visited_mask[i_loop] <= 1'b1;
                                component_count <= component_count + 4'd1;
                            end
                            i_loop <= i_loop + 4'd1;
                            state <= FIND_ROOT;
                        end else begin
                            temp_root <= parent[i_loop];
                        end
                    end
                end

                CALC_RESULT: begin
                    shift_count <= (M_reg + component_count) - N_reg;
                    pow2_val <= 32'd1;
                    i_loop <= 4'd0;
                    if (shift_count == 0) begin
                        result <= 32'd1;
                        state <= FINISH;
                    end else begin
                        state <= SHIFT_LOOP;
                    end
                end

                SHIFT_LOOP: begin
                    if (i_loop < shift_count) begin
                        pow2_val <= pow2_val * 32'd2;
                        i_loop <= i_loop + 4'd1;
                        state <= SHIFT_LOOP;
                    end else begin
                        result <= pow2_val;
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule