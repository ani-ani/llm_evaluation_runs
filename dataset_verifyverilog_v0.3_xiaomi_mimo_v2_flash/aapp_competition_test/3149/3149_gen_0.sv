module cookie_wall (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [31:0] omega,
    input wire [31:0] v0,
    input wire [31:0] theta,
    input wire [31:0] w,
    input wire [31:0] x0,
    input wire [31:0] x1,
    input wire [31:0] x2,
    input wire [31:0] x3,
    input wire [31:0] x4,
    input wire [31:0] x5,
    input wire [31:0] x6,
    input wire [31:0] x7,
    input wire [31:0] y0,
    input wire [31:0] y1,
    input wire [31:0] y2,
    input wire [31:0] y3,
    input wire [31:0] y4,
    input wire [31:0] y5,
    input wire [31:0] y6,
    input wire [31:0] y7,
    output reg [3:0] result_index,
    output reg [31:0] result_time,
    output reg done
);

    // Fixed-point constants (Q16.16)
    localparam [31:0] G = 32'sd642253;           // g = 9.81 m/s²
    localparam [31:0] MAX_TIME = 32'sd39321600;  // 600 seconds
    localparam [31:0] TIME_STEP = 32'sd6554;     // 0.1 seconds
    localparam [31:0] PI_TIMES_2 = 32'sd411775;  // 2π
    localparam [31:0] DEG_TO_RAD = 32'sd1143;    // π/180

    // State definitions
    localparam [3:0] S_IDLE          = 4'd0;
    localparam [3:0] S_COMPUTE_COM   = 4'd1;
    localparam [3:0] S_COMPUTE_VEL   = 4'd2;
    localparam [3:0] S_COMPUTE_REL   = 4'd3;
    localparam [3:0] S_INIT_TIME     = 4'd4;
    localparam [3:0] S_COMPUTE_TRIG  = 4'd5;
    localparam [3:0] S_COMPUTE_TRAJ  = 4'd6;
    localparam [3:0] S_CHECK_VERTEX  = 4'd7;
    localparam [3:0] S_NEXT_TIME     = 4'd8;
    localparam [3:0] S_DONE          = 4'd9;

    // Internal registers
    reg [3:0] state;
    reg [3:0] vertex_counter;
    reg [31:0] time_reg;
    reg [31:0] best_time;
    reg [3:0] best_index;
    reg found;
    reg [31:0] com_x;
    reg [31:0] com_y;
    reg [31:0] v0x;
    reg [31:0] v0y;
    reg [31:0] dx [0:7];
    reg [31:0] dy [0:7];
    reg [31:0] angle;
    reg [31:0] cos_phi;
    reg [31:0] sin_phi;
    reg [31:0] x_com_pos;
    reg [31:0] y_com_pos;
    reg [31:0] x_vertex;

    // Fixed-point multiplication
    function automatic [31:0] mul_fp;
        input [31:0] a;
        input [31:0] b;
        begin
            mul_fp = (a * b) >> 16;
        end
    endfunction

    // Fixed-point division
    function automatic [31:0] div_fp;
        input [31:0] a;
        input [31:0] b;
        begin
            div_fp = (a << 16) / b;
        end
    endfunction

    // Fixed-point division by small integer
    function automatic [31:0] div_int;
        input [31:0] a;
        input [3:0] b;
        begin
            div_int = a / b;
        end
    endfunction

    // Fixed-point trigonometric approximations (for small angles)
    function automatic [31:0] cos_approx;
        input [31:0] angle;
        begin
            // cos(φ) ≈ 1 - φ²/2 for small φ
            cos_approx = 32'sd65536 - mul_fp(angle, angle) / 2;
        end
    endfunction

    function automatic [31:0] sin_approx;
        input [31:0] angle;
        begin
            // sin(φ) ≈ φ for small φ
            sin_approx = angle;
        end
    endfunction

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            done <= 1'b0;
            found <= 1'b0;
            time_reg <= 32'd0;
            best_time <= 32'h7FFFFFFF;
            best_index <= 4'd0;
            vertex_counter <= 4'd0;
            com_x <= 32'd0;
            com_y <= 32'd0;
            v0x <= 32'd0;
            v0y <= 32'd0;
            angle <= 32'd0;
            cos_phi <= 32'd0;
            sin_phi <= 32'd0;
            x_com_pos <= 32'd0;
            y_com_pos <= 32'd0;
            x_vertex <= 32'd0;
            result_index <= 4'd0;
            result_time <= 32'd0;
            dx[0] <= 32'd0; dx[1] <= 32'd0; dx[2] <= 32'd0; dx[3] <= 32'd0;
            dx[4] <= 32'd0; dx[5] <= 32'd0; dx[6] <= 32'd0; dx[7] <= 32'd0;
            dy[0] <= 32'd0; dy[1] <= 32'd0; dy[2] <= 32'd0; dy[3] <= 32'd0;
            dy[4] <= 32'd0; dy[5] <= 32'd0; dy[6] <= 32'd0; dy[7] <= 32'd0;
        end else begin
            case (state)
                S_IDLE: begin
                    done <= 1'b0;
                    found <= 1'b0;
                    if (start) begin
                        state <= S_COMPUTE_COM;
                        vertex_counter <= 4'd0;
                        com_x <= 32'd0;
                        com_y <= 32'd0;
                    end
                end

                S_COMPUTE_COM: begin
                    case (vertex_counter)
                        4'd0: begin com_x <= x0; com_y <= y0; end
                        4'd1: begin com_x <= com_x + x1; com_y <= com_y + y1; end
                        4'd2: begin com_x <= com_x + x2; com_y <= com_y + y2; end
                        4'd3: begin com_x <= com_x + x3; com_y <= com_y + y3; end
                        4'd4: begin com_x <= com_x + x4; com_y <= com_y + y4; end
                        4'd5: begin com_x <= com_x + x5; com_y <= com_y + y5; end
                        4'd6: begin com_x <= com_x + x6; com_y <= com_y + y6; end
                        4'd7: begin com_x <= com_x + x7; com_y <= com_y + y7; end
                    endcase
                    if (vertex_counter == n - 1) begin
                        com_x <= div_int(com_x, n);
                        com_y <= div_int(com_y, n);
                        state <= S_COMPUTE_VEL;
                        vertex_counter <= 4'd0;
                    end else begin
                        vertex_counter <= vertex_counter + 4'd1;
                    end
                end

                S_COMPUTE_VEL: begin
                    // Compute velocity components from theta (degrees)
                    // Convert theta to radians: theta_rad = theta * π/180
                    // v0x = v0 * cos(theta_rad)
                    // v0y = v0 * sin(theta_rad)
                    // Using approximations: cos ≈ 1 - θ²/2, sin ≈ θ (when θ is small)
                    begin
                        reg [31:0] theta_rad;
                        theta_rad <= mul_fp(theta, DEG_TO_RAD);
                        v0x <= mul_fp(v0, cos_approx(theta_rad));
                        v0y <= mul_fp(v0, sin_approx(theta_rad));
                    end
                    state <= S_COMPUTE_REL;
                    vertex_counter <= 4'd0;
                end

                S_COMPUTE_REL: begin
                    case (vertex_counter)
                        4'd0: begin dx[0] <= x0 - com_x; dy[0] <= y0 - com_y; end
                        4'd1: begin dx[1] <= x1 - com_x; dy[1] <= y1 - com_y; end
                        4'd2: begin dx[2] <= x2 - com_x; dy[2] <= y2 - com_y; end
                        4'd3: begin dx[3] <= x3 - com_x; dy[3] <= y3 - com_y; end
                        4'd4: begin dx[4] <= x4 - com_x; dy[4] <= y4 - com_y; end
                        4'd5: begin dx[5] <= x5 - com_x; dy[5] <= y5 - com_y; end
                        4'd6: begin dx[6] <= x6 - com_x; dy[6] <= y6 - com_y; end
                        4'd7: begin dx[7] <= x7 - com_x; dy[7] <= y7 - com_y; end
                    endcase
                    if (vertex_counter == n - 1) begin
                        state <= S_INIT_TIME;
                    end else begin
                        vertex_counter <= vertex_counter + 4'd1;
                    end
                end

                S_INIT_TIME: begin
                    time_reg <= 32'd0;
                    vertex_counter <= 4'd0;
                    state <= S_COMPUTE_TRIG;
                end

                S_COMPUTE_TRIG: begin
                    // phi = omega * t
                    angle <= mul_fp(omega, time_reg);
                    // Limit angle to 0-2π range (simplified)
                    if (angle >= PI_TIMES_2) begin
                        angle <= angle - PI_TIMES_2;
                    end
                    cos_phi <= cos_approx(angle);
                    sin_phi <= sin_approx(angle);
                    state <= S_COMPUTE_TRAJ;
                end

                S_COMPUTE_TRAJ: begin
                    // x_com_pos = com_x + v0x * t
                    x_com_pos <= com_x + mul_fp(v0x, time_reg);
                    // y_com_pos = com_y + v0y * t - 0.5 * g * t^2
                    y_com_pos <= com_y + mul_fp(v0y, time_reg) - 
                                mul_fp(G, mul_fp(time_reg, time_reg)) / 2;
                    state <= S_CHECK_VERTEX;
                    vertex_counter <= 4'd0;
                end

                S_CHECK_VERTEX: begin
                    // x_vertex = x_com_pos + dx*cos(phi) + dy*sin(phi)
                    x_vertex <= x_com_pos + 
                               mul_fp(dx[vertex_counter], cos_phi) + 
                               mul_fp(dy[vertex_counter], sin_phi);
                    
                    if (x_vertex >= w && !found && time_reg > 0) begin
                        best_time <= time_reg;
                        best_index <= vertex_counter + 4'd1;
                        found <= 1'b1;
                    end
                    
                    if (vertex_counter == n - 1) begin
                        state <= S_NEXT_TIME;
                    end else begin
                        vertex_counter <= vertex_counter + 4'd1;
                    end
                end

                S_NEXT_TIME: begin
                    time_reg <= time_reg + TIME_STEP;
                    if (time_reg >= MAX_TIME || found) begin
                        state <= S_DONE;
                    end else begin
                        state <= S_COMPUTE_TRIG;
                    end
                end

                S_DONE: begin
                    result_index <= best_index;
                    result_time <= best_time;
                    done <= 1'b1;
                    if (!start) begin
                        state <= S_IDLE;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end
endmodule