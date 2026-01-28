module badge_access_counter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] S, D,
    input wire [3:0] lock_count,
    input wire [7:0] badge_max,
    input wire [31:0] lock0, lock1, lock2, lock3,
    input wire [31:0] lock4, lock5, lock6, lock7,
    input wire [31:0] lock8, lock9, lock10, lock11,
    input wire [31:0] lock12, lock13, lock14, lock15,
    output reg [7:0] result,
    output reg done
);

    localparam [3:0] S_IDLE = 4'd0;
    localparam [3:0] S_PREPARE_BADGE = 4'd1;
    localparam [3:0] S_BFS_INIT = 4'd2;
    localparam [3:0] S_BFS_DEQUEUE = 4'd3;
    localparam [3:0] S_BFS_CHECK_LOCK = 4'd4;
    localparam [3:0] S_BFS_DONE = 4'd5;
    localparam [3:0] S_INCREMENT_BADGE = 4'd6;
    localparam [3:0] S_FINISH = 4'd7;

    reg [3:0] state;
    reg [7:0] badge_id;
    reg [7:0] count;
    reg [15:0] active_mask_reg;
    reg [7:0] visited;
    reg [2:0] queue [0:7];
    reg [2:0] head;
    reg [2:0] tail;
    reg [2:0] current_u;
    reg [3:0] lock_idx;
    reg path_found;
    reg [2:0] v;

    wire [7:0] lock_a [0:15];
    wire [7:0] lock_b [0:15];
    wire [7:0] lock_x [0:15];
    wire [7:0] lock_y [0:15];

    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : lock_assign
            assign lock_a[i] = (i == 0) ? lock0[31:24] :
                               (i == 1) ? lock1[31:24] :
                               (i == 2) ? lock2[31:24] :
                               (i == 3) ? lock3[31:24] :
                               (i == 4) ? lock4[31:24] :
                               (i == 5) ? lock5[31:24] :
                               (i == 6) ? lock6[31:24] :
                               (i == 7) ? lock7[31:24] :
                               (i == 8) ? lock8[31:24] :
                               (i == 9) ? lock9[31:24] :
                               (i == 10) ? lock10[31:24] :
                               (i == 11) ? lock11[31:24] :
                               (i == 12) ? lock12[31:24] :
                               (i == 13) ? lock13[31:24] :
                               (i == 14) ? lock14[31:24] :
                                           lock15[31:24];
            assign lock_b[i] = (i == 0) ? lock0[23:16] :
                               (i == 1) ? lock1[23:16] :
                               (i == 2) ? lock2[23:16] :
                               (i == 3) ? lock3[23:16] :
                               (i == 4) ? lock4[23:16] :
                               (i == 5) ? lock5[23:16] :
                               (i == 6) ? lock6[23:16] :
                               (i == 7) ? lock7[23:16] :
                               (i == 8) ? lock8[23:16] :
                               (i == 9) ? lock9[23:16] :
                               (i == 10) ? lock10[23:16] :
                               (i == 11) ? lock11[23:16] :
                               (i == 12) ? lock12[23:16] :
                               (i == 13) ? lock13[23:16] :
                               (i == 14) ? lock14[23:16] :
                                           lock15[23:16];
            assign lock_x[i] = (i == 0) ? lock0[15:8] :
                               (i == 1) ? lock1[15:8] :
                               (i == 2) ? lock2[15:8] :
                               (i == 3) ? lock3[15:8] :
                               (i == 4) ? lock4[15:8] :
                               (i == 5) ? lock5[15:8] :
                               (i == 6) ? lock6[15:8] :
                               (i == 7) ? lock7[15:8] :
                               (i == 8) ? lock8[15:8] :
                               (i == 9) ? lock9[15:8] :
                               (i == 10) ? lock10[15:8] :
                               (i == 11) ? lock11[15:8] :
                               (i == 12) ? lock12[15:8] :
                               (i == 13) ? lock13[15:8] :
                               (i == 14) ? lock14[15:8] :
                                           lock15[15:8];
            assign lock_y[i] = (i == 0) ? lock0[7:0] :
                               (i == 1) ? lock1[7:0] :
                               (i == 2) ? lock2[7:0] :
                               (i == 3) ? lock3[7:0] :
                               (i == 4) ? lock4[7:0] :
                               (i == 5) ? lock5[7:0] :
                               (i == 6) ? lock6[7:0] :
                               (i == 7) ? lock7[7:0] :
                               (i == 8) ? lock8[7:0] :
                               (i == 9) ? lock9[7:0] :
                               (i == 10) ? lock10[7:0] :
                               (i == 11) ? lock11[7:0] :
                               (i == 12) ? lock12[7:0] :
                               (i == 13) ? lock13[7:0] :
                               (i == 14) ? lock14[7:0] :
                                           lock15[7:0];
        end
    endgenerate

    reg [15:0] active_mask_comb;
    always @(*) begin
        integer j;
        active_mask_comb = 16'd0;
        for (j = 0; j < 16; j = j + 1) begin
            if (j < lock_count) begin
                if ((lock_x[j] <= (badge_id + 1)) && ((badge_id + 1) <= lock_y[j])) begin
                    active_mask_comb[j] = 1'b1;
                end
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            done <= 1'b0;
            result <= 8'd0;
            badge_id <= 8'd0;
            count <= 8'd0;
            active_mask_reg <= 16'd0;
            visited <= 8'd0;
            head <= 3'd0;
            tail <= 3'd0;
            current_u <= 3'd0;
            lock_idx <= 4'd0;
            path_found <= 1'b0;
            v <= 3'd0;
        end else begin
            case (state)
                S_IDLE: begin
                    if (start) begin
                        badge_id <= 8'd0;
                        count <= 8'd0;
                        state <= S_PREPARE_BADGE;
                        done <= 1'b0;
                    end
                end
                S_PREPARE_BADGE: begin
                    active_mask_reg <= active_mask_comb;
                    state <= S_BFS_INIT;
                end
                S_BFS_INIT: begin
                    visited <= 8'd0;
                    head <= 3'd0;
                    tail <= 3'd0;
                    queue[0] <= S;
                    tail <= 3'd1;
                    visited[S] <= 1'b1;
                    path_found <= 1'b0;
                    lock_idx <= 4'd0;
                    state <= S_BFS_DEQUEUE;
                end
                S_BFS_DEQUEUE: begin
                    if (head != tail) begin
                        current_u <= queue[head];
                        head <= head + 3'd1;
                        lock_idx <= 4'd0;
                        state <= S_BFS_CHECK_LOCK;
                    end else begin
                        state <= S_BFS_DONE;
                    end
                end
                S_BFS_CHECK_LOCK: begin
                    if (current_u == D) begin
                        path_found <= 1'b1;
                        state <= S_BFS_DONE;
                    end else if (lock_idx < lock_count) begin
                        if (active_mask_reg[lock_idx] && (lock_a[lock_idx] == current_u)) begin
                            v <= lock_b[lock_idx];
                            if (!visited[lock_b[lock_idx]]) begin
                                queue[tail] <= lock_b[lock_idx];
                                tail <= tail + 3'd1;
                                visited[lock_b[lock_idx]] <= 1'b1;
                            end
                        end
                        lock_idx <= lock_idx + 4'd1;
                        state <= S_BFS_CHECK_LOCK;
                    end else begin
                        state <= S_BFS_DEQUEUE;
                    end
                end
                S_BFS_DONE: begin
                    if (path_found) begin
                        count <= count + 8'd1;
                    end
                    state <= S_INCREMENT_BADGE;
                end
                S_INCREMENT_BADGE: begin
                    if (badge_id + 8'd1 < badge_max) begin
                        badge_id <= badge_id + 8'd1;
                        state <= S_PREPARE_BADGE;
                    end else begin
                        state <= S_FINISH;
                    end
                end
                S_FINISH: begin
                    result <= count;
                    done <= 1'b1;
                    if (!start) begin
                        state <= S_IDLE;
                        done <= 1'b0;
                    end
                end
                default: state <= S_IDLE;
            endcase
        end
    end
endmodule