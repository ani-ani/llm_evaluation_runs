module right_triangle_counter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] points_x [0:15],
    input wire signed [7:0] points_y [0:15],
    input wire [4:0] num_points,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] LOOP_I = 3'd2;
    localparam [2:0] LOOP_J = 3'd3;
    localparam [2:0] LOOP_K = 3'd4;
    localparam [2:0] CHECK = 3'd5;
    localparam [2:0] FINISH = 3'd6;

    // Registers for state and counters
    reg [2:0] state, next_state;
    reg [3:0] i_reg, j_reg, k_reg;
    reg [3:0] i_next, j_next, k_next;

    // Registers for differences and dot products
    reg signed [15:0] dx_ij, dy_ij;
    reg signed [15:0] dx_ik, dy_ik;
    reg signed [15:0] dx_ji, dy_ji;
    reg signed [15:0] dx_jk, dy_jk;
    reg signed [15:0] dx_ki, dy_ki;
    reg signed [15:0] dx_kj, dy_kj;

    reg signed [31:0] dot_ij_ik, dot_ji_jk, dot_ki_kj;

    // Result counter
    reg [15:0] count_reg;

    // Cycle counter to prevent infinite loops
    reg [11:0] cycle_count;
    localparam [11:0] MAX_CYCLES = 12'd4096;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 12'd0;
            i_reg <= 4'd0;
            j_reg <= 4'd0;
            k_reg <= 4'd0;
            count_reg <= 16'd0;
        end else begin
            state <= next_state;
            i_reg <= i_next;
            j_reg <= j_next;
            k_reg <= k_next;
            count_reg <= count_reg + (state == CHECK && (dot_ij_ik == 32'd0 || dot_ji_jk == 32'd0 || dot_ki_kj == 32'd0)) ? 16'd1 : 16'd0;
            
            if (state != IDLE && state != FINISH) begin
                cycle_count <= cycle_count + 12'd1;
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        i_next = i_reg;
        j_next = j_reg;
        k_next = k_reg;
        done = 1'b0;
        result = 16'd0;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                end
            end

            INIT: begin
                next_state = LOOP_I;
                i_next = 4'd0;
                j_next = 4'd0;
                k_next = 4'd0;
                count_reg = 16'd0;
                cycle_count = 12'd0;
            end

            LOOP_I: begin
                if (i_reg < num_points - 3) begin
                    next_state = LOOP_J;
                    j_next = i_reg + 4'd1;
                end else begin
                    next_state = FINISH;
                end
            end

            LOOP_J: begin
                if (j_reg < num_points - 2) begin
                    next_state = LOOP_K;
                    k_next = j_reg + 4'd1;
                end else begin
                    next_state = LOOP_I;
                    i_next = i_reg + 4'd1;
                end
            end

            LOOP_K: begin
                if (k_reg < num_points - 1) begin
                    next_state = CHECK;
                end else begin
                    next_state = LOOP_J;
                    j_next = j_reg + 4'd1;
                end
            end

            CHECK: begin
                next_state = LOOP_K;
                k_next = k_reg + 4'd1;
            end

            FINISH: begin
                done = 1'b1;
                result = count_reg;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
        
        // Prevent infinite loops
        if (cycle_count >= MAX_CYCLES) begin
            next_state = IDLE;
        end
    end

    // Calculate differences and dot products
    always @(*) begin
        dx_ij = points_x[j_reg] - points_x[i_reg];
        dy_ij = points_y[j_reg] - points_y[i_reg];
        dx_ik = points_x[k_reg] - points_x[i_reg];
        dy_ik = points_y[k_reg] - points_y[i_reg];
        
        dx_ji = -dx_ij;
        dy_ji = -dy_ij;
        dx_jk = points_x[k_reg] - points_x[j_reg];
        dy_jk = points_y[k_reg] - points_y[j_reg];
        
        dx_ki = -dx_ik;
        dy_ki = -dy_ik;
        dx_kj = -dx_jk;
        dy_kj = -dy_jk;
        
        dot_ij_ik = $signed(dx_ij) * $signed(dx_ik) + $signed(dy_ij) * $signed(dy_ik);
        dot_ji_jk = $signed(dx_ji) * $signed(dx_jk) + $signed(dy_ji) * $signed(dy_jk);
        dot_ki_kj = $signed(dx_ki) * $signed(dx_kj) + $signed(dy_ki) * $signed(dy_kj);
    end

endmodule