module greedy_tower (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [19:0] m,
    output reg [4:0] blocks,
    output reg [19:0] volume,
    output reg done
);

    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] CUBE_ROOT = 4'd1;
    localparam [3:0] EXPLORE_A = 4'd2;
    localparam [3:0] EXPLORE_B = 4'd3;
    localparam [3:0] UPDATE_BEST = 4'd4;
    localparam [3:0] POP_STACK = 4'd5;
    localparam [3:0] FINISH = 4'd6;
    localparam [4:0] MAX_DEPTH = 5'd18;
    localparam [5:0] MAX_ITER = 6'd100;

    reg [3:0] state, next_state;
    reg [5:0] counter, next_counter;
    reg [4:0] stack_ptr, next_stack_ptr;
    reg [19:0] stack_m[0:17], next_stack_m[0:17];
    reg [4:0] stack_blocks[0:17], next_stack_blocks[0:17];
    reg [19:0] stack_volume[0:17], next_stack_volume[0:17];
    reg [4:0] best_blocks, next_best_blocks;
    reg [19:0] best_volume, next_best_volume;
    reg [6:0] a, next_a, low, next_low, high, next_high;
    reg [35:0] a_cube, next_a_cube, a_minus_1_cube, next_a_minus_1_cube;
    reg [35:0] new_m, next_new_m, new_vol, next_new_vol;
    reg [4:0] new_blocks, next_new_blocks;
    reg [1:0] explore_path, next_explore_path;
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 6'd0;
            stack_ptr <= 5'd0;
            for (i = 0; i < 18; i = i + 1) begin
                stack_m[i] <= 20'd0;
                stack_blocks[i] <= 5'd0;
                stack_volume[i] <= 20'd0;
            end
            best_blocks <= 5'd0;
            best_volume <= 20'd0;
            a <= 7'd0;
            low <= 7'd0;
            high <= 7'd0;
            a_cube <= 36'd0;
            a_minus_1_cube <= 36'd0;
            new_m <= 20'd0;
            new_vol <= 20'd0;
            new_blocks <= 5'd0;
            explore_path <= 2'd0;
            blocks <= 5'd0;
            volume <= 20'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            counter <= next_counter;
            stack_ptr <= next_stack_ptr;
            for (i = 0; i < 18; i = i + 1) begin
                stack_m[i] <= next_stack_m[i];
                stack_blocks[i] <= next_stack_blocks[i];
                stack_volume[i] <= next_stack_volume[i];
            end
            best_blocks <= next_best_blocks;
            best_volume <= next_best_volume;
            a <= next_a;
            low <= next_low;
            high <= next_high;
            a_cube <= next_a_cube;
            a_minus_1_cube <= next_a_minus_1_cube;
            new_m <= next_new_m;
            new_vol <= next_new_vol;
            new_blocks <= next_new_blocks;
            explore_path <= next_explore_path;
            if (state == FINISH) begin
                blocks <= best_blocks;
                volume <= best_volume;
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end

    always @(*) begin
        next_state = state;
        next_counter = counter;
        next_stack_ptr = stack_ptr;
        for (i = 0; i < 18; i = i + 1) begin
            next_stack_m[i] = stack_m[i];
            next_stack_blocks[i] = stack_blocks[i];
            next_stack_volume[i] = stack_volume[i];
        end
        next_best_blocks = best_blocks;
        next_best_volume = best_volume;
        next_a = a;
        next_low = low;
        next_high = high;
        next_a_cube = a_cube;
        next_a_minus_1_cube = a_minus_1_cube;
        next_new_m = new_m;
        next_new_vol = new_vol;
        next_new_blocks = new_blocks;
        next_explore_path = explore_path;

        case (state)
            IDLE: begin
                if (start) begin
                    next_stack_ptr = 5'd0;
                    next_best_blocks = 5'd0;
                    next_best_volume = 20'd0;
                    next_state = CUBE_ROOT;
                    next_low = 7'd0;
                    next_high = 7'd100;
                    next_counter = 6'd0;
                    next_a_cube = 36'd0;
                    next_explore_path = 2'd0;
                end
            end

            CUBE_ROOT: begin
                if (next_counter == 6'd0) begin
                    next_a = (next_low + next_high) >> 1;
                end else if (counter <= 6'd7) begin
                    if (next_a_cube > m) begin
                        next_high = next_a - 7'd1;
                    end else begin
                        next_low = next_a + 7'd1;
                    end
                    next_a = (next_low + next_high) >> 1;
                end
                next_a_cube = next_a * next_a * next_a;
                if (counter == 6'd7) begin
                    if (next_a_cube <= m) begin
                        next_a = next_a + 7'd1;
                        next_a_cube = next_a * next_a * next_a;
                    end
                    next_a_minus_1_cube = (next_a - 7'd1) * (next_a - 7'd1) * (next_a - 7'd1);
                    next_counter = 6'd0;
                    next_state = EXPLORE_A;
                end else begin
                    next_counter = counter + 6'd1;
                    next_state = CUBE_ROOT;
                end
            end

            EXPLORE_A: begin
                if (next_explore_path == 2'd0) begin
                    next_new_m = m - next_a_cube;
                    next_new_blocks = 5'd1;
                    next_new_vol = 20'd0;
                    if (next_new_m == 20'd0) begin
                        if (next_new_blocks > best_blocks || (next_new_blocks == best_blocks && next_new_vol < best_volume)) begin
                            next_best_blocks = next_new_blocks;
                            next_best_volume = next_new_vol;
                        end
                        next_state = EXPLORE_B;
                    end else if (next_a_cube > m) begin
                        next_state = EXPLORE_B;
                    end else if (next_stack_ptr < MAX_DEPTH) begin
                        next_stack_m[next_stack_ptr] = next_new_m;
                        next_stack_blocks[next_stack_ptr] = next_new_blocks;
                        next_stack_volume[next_stack_ptr] = next_new_vol;
                        next_stack_ptr = next_stack_ptr + 5'd1;
                        next_low = 7'd0;
                        next_high = 7'd100;
                        next_counter = 6'd0;
                        next_state = CUBE_ROOT;
                        next_explore_path = 2'd0;
                    end else begin
                        next_state = EXPLORE_B;
                    end
                end else begin
                    next_state = EXPLORE_B;
                end
            end

            EXPLORE_B: begin
                if (next_explore_path == 2'd1 || next_explore_path == 2'd0) begin
                    next_new_m = next_a_minus_1_cube - 20'd1 - (next_a * next_a * 3'd3 - next_a * 3'd3 + 20'd1);
                    next_new_m = next_a_minus_1_cube - 20'd1 - (36'd3 * next_a * next_a - 36'd3 * next_a + 36'd1);
                    next_new_blocks = 5'd1;
                    next_new_vol = 20'd0;
                    if (next_new_m == 20'd0) begin
                        if (next_new_blocks > best_blocks || (next_new_blocks == best_blocks && next_new_vol < best_volume)) begin
                            next_best_blocks = next_new_blocks;
                            next_best_volume = next_new_vol;
                        end
                        next_state = UPDATE_BEST;
                    end else if (next_a == 7'd1 || next_a_minus_1_cube <= 20'd1) begin
                        next_state = UPDATE_BEST;
                    end else if (next_stack_ptr < MAX_DEPTH) begin
                        next_stack_m[next_stack_ptr] = next_new_m;
                        next_stack_blocks[next_stack_ptr] = next_new_blocks;
                        next_stack_volume[next_stack_ptr] = next_new_vol;
                        next_stack_ptr = next_stack_ptr + 5'd1;
                        next_low = 7'd0;
                        next_high = 7'd100;
                        next_counter = 6'd0;
                        next_state = CUBE_ROOT;
                        next_explore_path = 2'd1;
                    end else begin
                        next_state = UPDATE_BEST;
                    end
                end else begin
                    next_state = UPDATE_BEST;
                end
            end

            UPDATE_BEST: begin
                if (next_explore_path == 2'd2) begin
                    next_explore_path = 2'd0;
                    next_state = POP_STACK;
                end else begin
                    next_explore_path = next_explore_path + 2'd1;
                    if (next_a > 7'd1 && next_explore_path < 2'd2) begin
                        next_state = EXPLORE_A;
                    end else begin
                        next_state = POP_STACK;
                    end
                end
            end

            POP_STACK: begin
                if (stack_ptr > 5'd0) begin
                    next_stack_ptr = stack_ptr - 5'd1;
                    next_new_m = stack_m[stack_ptr - 5'd1];
                    next_new_blocks = stack_blocks[stack_ptr - 5'd1] + 5'd1;
                    next_new_vol = stack_volume[stack_ptr - 5'd1] + 20'd1;
                    if (next_new_m == 20'd0) begin
                        if (next_new_blocks > best_blocks || (next_new_blocks == best_blocks && next_new_vol < best_volume)) begin
                            next_best_blocks = next_new_blocks;
                            next_best_volume = next_new_vol;
                        end
                        next_state = POP_STACK;
                    end else begin
                        next_low = 7'd0;
                        next_high = 7'd100;
                        next_counter = 6'd0;
                        next_state = CUBE_ROOT;
                        next_explore_path = 2'd0;
                        next_stack_m[next_stack_ptr] = next_new_m;
                        next_stack_blocks[next_stack_ptr] = next_new_blocks;
                        next_stack_volume[next_stack_ptr] = next_new_vol;
                        next_stack_ptr = next_stack_ptr + 5'd1;
                    end
                end else begin
                    next_state = FINISH;
                end
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

endmodule