module goat_rope(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [9:0] x0,
    input wire [9:0] y0,
    input wire [9:0] x1,
    input wire [9:0] y1,
    input wire [9:0] x2,
    input wire [9:0] y2,
    output reg [31:0] result,
    output reg done
);

    // Parameters
    localparam [1:0] N = 2'd3; // Number of posts
    localparam [3:0] COORD_WIDTH = 4'd10;
    localparam [5:0] DATA_WIDTH = 6'd20;
    localparam [6:0] RESULT_WIDTH = 7'd32;
    localparam [3:0] MAX_CYCLES = 4'd50;

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] CALC_DX   = 3'd1;
    localparam [2:0] CALC_DY   = 3'd2;
    localparam [2:0] CALC_SQ   = 3'd3;
    localparam [2:0] CALC_SQRT = 3'd4;
    localparam [2:0] SUM_DIST  = 3'd5;
    localparam [2:0] DIVIDE    = 3'd6;
    localparam [2:0] FINISH    = 3'd7;

    // Registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] cycle_count;
    reg [1:0] pair_index; // 0: (0,1), 1: (0,2), 2: (1,2)
    reg [9:0] x_i, x_j, y_i, y_j;
    reg [9:0] dx, dy;
    reg [19:0] dist_sq;
    reg [15:0] dist_scaled; // distance * 100
    reg [31:0] sum_dist_scaled;
    reg [31:0] temp_result;
    reg [7:0] sqrt_iter;
    reg [15:0] sqrt_rem;
    reg [15:0] sqrt_root;

    // Combinational helpers for sqrt
    wire [31:0] sqrt_arg = {dist_sq, 12'd0}; // Multiply by 4096 for better precision
    wire [15:0] sqrt_new_root;
    wire [15:0] sqrt_new_rem;
    wire [15:0] sqrt_test;
    
    assign sqrt_test = (sqrt_root << 1) | 16'd1;
    assign sqrt_new_rem = (sqrt_rem << 2) + sqrt_arg[(31 - (sqrt_iter << 1)) -: 2];
    assign sqrt_new_root = (sqrt_new_rem >= sqrt_test) ? sqrt_test : sqrt_root;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 4'd0;
            pair_index <= 2'd0;
            x_i <= 10'd0;
            x_j <= 10'd0;
            y_i <= 10'd0;
            y_j <= 10'd0;
            dx <= 10'd0;
            dy <= 10'd0;
            dist_sq <= 20'd0;
            dist_scaled <= 16'd0;
            sum_dist_scaled <= 32'd0;
            temp_result <= 32'd0;
            sqrt_iter <= 8'd0;
            sqrt_rem <= 16'd0;
            sqrt_root <= 16'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    pair_index <= 2'd0;
                    sum_dist_scaled <= 32'd0;
                    sqrt_iter <= 8'd0;
                    if (start) begin
                        // Set first pair (0, 1)
                        x_i <= x0;
                        x_j <= x1;
                        y_i <= y0;
                        y_j <= y1;
                    end
                end

                CALC_DX: begin
                    if (x_i > x_j) begin
                        dx <= x_i - x_j;
                    end else begin
                        dx <= x_j - x_i;
                    end
                end

                CALC_DY: begin
                    if (y_i > y_j) begin
                        dy <= y_i - y_j;
                    end else begin
                        dy <= y_j - y_i;
                    end
                end

                CALC_SQ: begin
                    // dx*dx + dy*dy, result 20 bits max (1000^2 * 2 = 2,000,000 < 2^21)
                    dist_sq <= (dx * dx) + (dy * dy);
                end

                CALC_SQRT: begin
                    // Integer square root calculation
                    // dist_scaled = sqrt(dist_sq * 10000) = sqrt(dist_sq) * 100
                    // We calculate sqrt(dist_sq * 4096) * (100 / 64) for better precision
                    if (sqrt_iter < 8'd16) begin
                        sqrt_root <= sqrt_new_root;
                        sqrt_rem <= sqrt_new_rem;
                        sqrt_iter <= sqrt_iter + 8'd1;
                    end else begin
                        // Scale: sqrt_root * 100 / 64
                        dist_scaled <= (sqrt_root * 100) >> 6;
                        sqrt_iter <= 8'd0;
                        sqrt_root <= 16'd0;
                        sqrt_rem <= 16'd0;
                    end
                end

                SUM_DIST: begin
                    sum_dist_scaled <= sum_dist_scaled + {16'd0, dist_scaled};
                end

                DIVIDE: begin
                    // result = sum / 2 (for triangle perimeter)
                    temp_result <= sum_dist_scaled >> 1;
                end

                FINISH: begin
                    result <= temp_result;
                    done <= 1'b1;
                end
            endcase

            if (state != IDLE) begin
                cycle_count <= cycle_count + 4'd1;
            end
        end
    end

    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CALC_DX;
                end
            end

            CALC_DX: begin
                next_state = CALC_DY;
            end

            CALC_DY: begin
                next_state = CALC_SQ;
            end

            CALC_SQ: begin
                next_state = CALC_SQRT;
            end

            CALC_SQRT: begin
                if (sqrt_iter >= 8'd16) begin
                    next_state = SUM_DIST;
                end
            end

            SUM_DIST: begin
                // Check which pair we're on
                if (pair_index == 2'd2) begin
                    // Done with all pairs for N=3
                    next_state = DIVIDE;
                end else if (pair_index == 2'd1 && N == 2'd2) begin
                    // Done with single pair for N=2
                    next_state = FINISH;
                end else begin
                    // Set next pair
                    next_state = CALC_DX;
                end
            end

            DIVIDE: begin
                next_state = FINISH;
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase

        // Override for N=2 (single pair only)
        if (state == SUM_DIST && pair_index == 2'd0 && N == 2'd2) begin
            next_state = FINISH;
        end
    end

    // Pair selection logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pair_index <= 2'd0;
        end else if (state == SUM_DIST) begin
            if (pair_index == 2'd0) begin
                pair_index <= 2'd1;
                if (N == 2'd3) begin
                    x_i <= x0;
                    x_j <= x2;
                    y_i <= y0;
                    y_j <= y2;
                end
            end else if (pair_index == 2'd1 && N == 2'd3) begin
                pair_index <= 2'd2;
                x_i <= x1;
                x_j <= x2;
                y_i <= y1;
                y_j <= y2;
            end
        end
    end

    // Timeout protection
    always @(*) begin
        if (state != IDLE && cycle_count >= MAX_CYCLES) begin
            next_state = IDLE;
        end
    end

endmodule