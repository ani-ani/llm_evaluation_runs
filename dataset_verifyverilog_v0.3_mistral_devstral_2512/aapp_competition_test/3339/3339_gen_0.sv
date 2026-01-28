module evenland(
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

    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] COLLECT = 4'd1;
    localparam [3:0] FIND = 4'd2;
    localparam [3:0] PROCESS_RESULT = 4'd3;
    localparam [3:0] UNION = 4'd4;
    localparam [3:0] CHECK_DONE = 4'd5;
    localparam [3:0] COMPUTE_INIT = 4'd6;
    localparam [3:0] COMPUTE_LOOP = 4'd7;
    localparam [3:0] COMPUTE_RESULT = 4'd8;
    localparam [3:0] DONE = 4'd9;

    reg [3:0] state;
    reg [3:0] next_state;
    reg [3:0] parent [0:7];
    reg [4:0] edge_count;
    reg [4:0] M_reg;
    reg [3:0] N_reg;
    reg [2:0] temp_a;
    reg [2:0] temp_b;
    reg [2:0] find_target;
    reg [2:0] root_a;
    reg [2:0] root_b;
    reg [2:0] root_temp;
    reg [1:0] phase;
    reg [2:0] find_iter;
    reg [3:0] i;
    reg [3:0] component_count;
    reg [7:0] seen_roots;
    reg [4:0] shift_amount;
    reg [31:0] result_reg;
    reg done_reg;

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = COLLECT;
            COLLECT: begin
                if (edge_count < M_reg && edge_valid) next_state = FIND;
                else if (edge_count == M_reg) next_state = COMPUTE_INIT;
            end
            FIND: begin
                if (parent[find_target] == find_target) next_state = PROCESS_RESULT;
                else if (find_iter >= 7) next_state = PROCESS_RESULT;
                else next_state = FIND;
            end
            PROCESS_RESULT: begin
                if (phase == 2'd1) next_state = FIND;
                else if (phase == 2'd2) next_state = UNION;
                else if (phase == 2'd3) next_state = COMPUTE_LOOP;
            end
            UNION: next_state = CHECK_DONE;
            CHECK_DONE: begin
                if (edge_count == M_reg) next_state = COMPUTE_INIT;
                else next_state = COLLECT;
            end
            COMPUTE_INIT: next_state = COMPUTE_LOOP;
            COMPUTE_LOOP: begin
                if (i >= N_reg) next_state = COMPUTE_RESULT;
                else next_state = FIND;
            end
            COMPUTE_RESULT: next_state = DONE;
            DONE: next_state = DONE;
            default: next_state = IDLE;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            edge_count <= 5'd0;
            done_reg <= 1'b0;
            result <= 32'd0;
            done <= 1'b0;
            parent[0] <= 4'd0;
            parent[1] <= 4'd1;
            parent[2] <= 4'd2;
            parent[3] <= 4'd3;
            parent[4] <= 4'd4;
            parent[5] <= 4'd5;
            parent[6] <= 4'd6;
            parent[7] <= 4'd7;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    if (start) begin
                        parent[0] <= 4'd0;
                        parent[1] <= 4'd1;
                        parent[2] <= 4'd2;
                        parent[3] <= 4'd3;
                        parent[4] <= 4'd4;
                        parent[5] <= 4'd5;
                        parent[6] <= 4'd6;
                        parent[7] <= 4'd7;
                        edge_count <= 5'd0;
                        M_reg <= M;
                        N_reg <= N;
                        done_reg <= 1'b0;
                        result <= 32'd0;
                        done <= 1'b0;
                    end
                end
                COLLECT: begin
                    if (edge_count < M_reg && edge_valid) begin
                        temp_a <= edge_a - 3'd1;
                        temp_b <= edge_b - 3'd1;
                        edge_count <= edge_count + 5'd1;
                        phase <= 2'd1;
                        find_target <= edge_a - 3'd1;
                        find_iter <= 3'd0;
                    end
                end
                FIND: begin
                    if (parent[find_target] == find_target) begin
                        root_temp <= find_target;
                    end else if (find_iter >= 3'd7) begin
                        root_temp <= find_target;
                    end else begin
                        find_target <= parent[find_target];
                        find_iter <= find_iter + 3'd1;
                    end
                end
                PROCESS_RESULT: begin
                    if (phase == 2'd1) begin
                        root_a <= root_temp;
                        phase <= 2'd2;
                        find_target <= temp_b;
                        find_iter <= 3'd0;
                    end else if (phase == 2'd2) begin
                        root_b <= root_temp;
                    end else if (phase == 2'd3) begin
                        if (!seen_roots[root_temp]) begin
                            seen_roots[root_temp] <= 1'b1;
                            component_count <= component_count + 4'd1;
                        end
                        i <= i + 4'd1;
                    end
                end
                UNION: begin
                    if (root_a != root_b) begin
                        parent[root_a] <= root_b;
                    end
                end
                CHECK_DONE: begin
                end
                COMPUTE_INIT: begin
                    i <= 4'd0;
                    component_count <= 4'd0;
                    seen_roots <= 8'd0;
                end
                COMPUTE_LOOP: begin
                    if (i < N_reg) begin
                        phase <= 2'd3;
                        find_target <= i;
                        find_iter <= 3'd0;
                    end
                end
                COMPUTE_RESULT: begin
                    shift_amount <= (M_reg + component_count) - N_reg;
                    result <= 32'd1 << shift_amount;
                    done_reg <= 1'b1;
                    done <= 1'b1;
                end
                DONE: begin
                end
            endcase
        end
    end

endmodule