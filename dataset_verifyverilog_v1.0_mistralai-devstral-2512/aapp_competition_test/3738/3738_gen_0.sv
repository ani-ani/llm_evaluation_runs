module robot_reachability(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [13:0] a,
    input wire signed [13:0] b,
    input wire [3:0] seq_len,
    input wire [1:0] cmd [0:15],
    output reg done,
    output reg result
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] PRECALC = 3'd1;
    localparam [2:0] CHECK   = 3'd2;
    localparam [2:0] FINISH  = 3'd3;

    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Intermediate positions (17 positions: start + 16 commands)
    reg signed [15:0] x_pos [0:16];
    reg signed [15:0] y_pos [0:16];

    // Net displacement per full sequence
    reg signed [5:0] dx;
    reg signed [5:0] dy;

    // Check loop variables
    reg [4:0] check_idx;
    reg signed [15:0] xi;
    reg signed [15:0] yi;
    reg signed [15:0] dx_temp;
    reg signed [15:0] dy_temp;
    reg signed [15:0] quotient_x;
    reg signed [15:0] quotient_y;
    reg signed [15:0] remainder_x;
    reg signed [15:0] remainder_y;
    reg same_sign_x;
    reg same_sign_y;
    reg valid_check;

    // Command decoding
    always @(*) begin
        dx = 6'd0;
        dy = 6'd0;
        if (seq_len > 4'd0) begin
            for (integer i = 0; i < seq_len; i = i + 1) begin
                case (cmd[i])
                    2'd0: dy = dy + 6'd1;  // 'U'
                    2'd1: dy = dy - 6'd1;  // 'D'
                    2'd2: dx = dx - 6'd1;  // 'L'
                    2'd3: dx = dx + 6'd1;  // 'R'
                endcase
            end
        end
    end

    // Precalculate positions
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 1'b0;
            cycle_count <= 8'd0;
            check_idx <= 5'd0;
            for (integer i = 0; i < 17; i = i + 1) begin
                x_pos[i] <= 16'd0;
                y_pos[i] <= 16'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= PRECALC;
                    end
                end

                PRECALC: begin
                    // Initialize positions
                    x_pos[0] <= 16'd0;
                    y_pos[0] <= 16'd0;
                    for (integer i = 1; i <= seq_len; i = i + 1) begin
                        x_pos[i] <= x_pos[i-1];
                        y_pos[i] <= y_pos[i-1];
                        case (cmd[i-1])
                            2'd0: y_pos[i] <= y_pos[i] + 16'd1;  // 'U'
                            2'd1: y_pos[i] <= y_pos[i] - 16'd1;  // 'D'
                            2'd2: x_pos[i] <= x_pos[i] - 16'd1;  // 'L'
                            2'd3: x_pos[i] <= x_pos[i] + 16'd1;  // 'R'
                        endcase
                    end
                    state <= CHECK;
                    check_idx <= 5'd0;
                end

                CHECK: begin
                    cycle_count <= cycle_count + 8'd1;
                    xi <= x_pos[check_idx];
                    yi <= y_pos[check_idx];

                    // Calculate differences
                    dx_temp <= a - xi;
                    dy_temp <= b - yi;

                    // Check conditions
                    if (dx == 6'd0) begin
                        if (dy == 6'd0) begin
                            // Both zero: only reachable if already at target
                            if (xi == a && yi == b) begin
                                result <= 1'b1;
                            end
                        end else begin
                            // dx == 0, dy != 0
                            if (a == xi) begin
                                same_sign_y <= (dy_temp[15] == dy[5]);
                                if (same_sign_y && (dy_temp % dy == 6'd0)) begin
                                    result <= 1'b1;
                                end
                            end
                        end
                    end else if (dy == 6'd0) begin
                        // dy == 0, dx != 0
                        if (b == yi) begin
                            same_sign_x <= (dx_temp[15] == dx[5]);
                            if (same_sign_x && (dx_temp % dx == 6'd0)) begin
                                result <= 1'b1;
                            end
                        end
                    end else begin
                        // Both dx and dy != 0
                        if (dx_temp % dx == 6'd0 && dy_temp % dy == 6'd0) begin
                            quotient_x <= dx_temp / dx;
                            quotient_y <= dy_temp / dy;
                            if (quotient_x == quotient_y && quotient_x >= 16'd0) begin
                                result <= 1'b1;
                            end
                        end
                    end

                    // Move to next check or finish
                    if (check_idx == 5'd16 || result == 1'b1) begin
                        state <= FINISH;
                    end else begin
                        check_idx <= check_idx + 5'd1;
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