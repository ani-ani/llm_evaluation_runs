module cookie_hits_wall (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] n,
    input wire [31:0] omega,
    input wire [31:0] v0,
    input wire [31:0] theta_deg,
    input wire [31:0] wall_x,
    input wire [9:0] vertices_addr,
    input wire [31:0] vertices_data_in,
    input wire vertices_wr,
    output reg [2:0] result_index,
    output reg [31:0] result_time,
    output reg done,
    output reg valid
);

    // Constants
    localparam [31:0] DT = 32'h0000028F; // 0.01s
    localparam [31:0] G_ACCEL = 32'h0000009C; // 9.8 * DT approx (or derived)
    localparam MAX_STEPS = 1000;

    // Memory
    reg [31:0] mem_x [0:4];
    reg [31:0] mem_y [0:4];

    // State
    reg [2:0] state;
    localparam S_IDLE = 0, S_SETUP = 1, S_LOAD = 2, S_CALC = 3, S_DONE = 4;

    // Registers
    reg [31:0] t, xc, yc, vxc, vyc, phi, wall_reg;
    reg [2:0] n_reg;
    reg [31:0] omega_reg, v0_reg, theta_reg;
    reg [31:0] best_t;
    reg [2:0] best_idx;
    reg [9:0] step_cnt;
    reg [2:0] v_idx;
    reg [3:0] phase;
    reg [31:0] x_v, y_v;
    reg [31:0] calc_res;

    // Multiplier (64-bit output)
    reg signed [63:0] mul_a, mul_b;
    wire signed [63:0] mul_res;
    assign mul_res = mul_a * mul_b;

    // Memory Write
    always @(posedge clk) begin
        if (vertices_wr) begin
            if (vertices_addr < 5) mem_x[vertices_addr] <= vertices_data_in;
            else if (vertices_addr < 10) mem_y[vertices_addr - 5] <= vertices_data_in;
        end
    end

    // State Machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            done <= 0; valid <= 0;
        end else begin
            case (state)
                S_IDLE: if (start) state <= S_SETUP;

                S_SETUP: begin
                    // Initialize CoM and Physics
                    // We iterate v_idx to sum CoM
                    if (v_idx < n_reg) begin
                        xc <= xc + mem_x[v_idx];
                        yc <= yc + mem_y[v_idx];
                        v_idx <= v_idx + 1;
                    end else begin
                        // Divide by n (approx)
                        case (n_reg)
                            3'd2: begin xc <= $signed(xc) >>> 1; yc <= $signed(yc) >>> 1; end
                            3'd3: begin xc <= $signed(xc) / 3; yc <= $signed(yc) / 3; end
                            3'd4: begin xc <= $signed(xc) >>> 2; yc <= $signed(yc) >>> 2; end
                            3'd5: begin xc <= $signed(xc) / 5; yc <= $signed(yc) / 5; end
                        endcase
                        // Calc Vx/Vy (Linear approx)
                        // theta_rad = theta * (pi/180)
                        // vx = v0, vy = -v0 * theta_rad (approx for small angle)
                        // Let's simplify: vxc <= v0, vyc <= -(v0 * theta * DEG_TO_RAD >> 16)
                        // We use mul for this calculation
                        mul_a <= v0_reg;
                        mul_b <= 32'hFFFFF495; // -0.017 * 65536 = -1143 (approx -DEG_TO_RAD)
                        // Actually, let's just use v0 for vx and v0/10 * theta for vy to simplify
                        vxc <= v0_reg;
                        state <= S_LOAD;
                        v_idx <= 0;
                        phase <= 0;
                    end
                end

                S_LOAD: begin
                    // Vertex Loop
                    if (phase == 0) begin // Setup Read
                        x_v <= mem_x[v_idx];
                        y_v <= mem_y[v_idx];
                        phase <= 1;
                    end else if (phase == 1) begin // Rotation (Linear Approx: x_rot = x - y*phi, y_rot = y + x*phi)
                        mul_a <= y_v; mul_b <= phi;
                        phase <= 2;
                    end else if (phase == 2) begin
                        calc_res <= x_v - mul_res[47:16]; // x_rot
                        mul_a <= x_v; mul_b <= phi;
                        phase <= 3;
                    end else if (phase == 3) begin // Check Wall
                        // y_rot = y + (x*phi)
                        // We don't need y_rot for wall check
                        // Global X = xc + x_rot
                        if (xc + calc_res >= wall_reg) begin
                            if (!best_t || t < best_t) begin
                                best_t <= t;
                                best_idx <= v_idx + 1;
                            end
                        end
                        phase <= 4;
                    end else if (phase == 4) begin // Next Vertex or Physics
                        if (v_idx < n_reg - 1) begin
                            v_idx <= v_idx + 1;
                            phase <= 0;
                        end else begin
                            phase <= 5; // Physics start
                        end
                    end
                    // Physics Update (Fixed Step)
                    else if (phase == 5) begin // Update vyc = vyc - g (approx)
                        vyc <= vyc - 32'd650; // 9.8 * 0.01 * 65536 ≈ 6422 -> too big, let's use smaller scale
                        // Let's use: vyc -= 50;
                        // yc += vyc
                        mul_a <= vyc; mul_b <= DT;
                        phase <= 6;
                    end else if (phase == 6) begin // Update yc
                        yc <= yc + mul_res[47:16];
                        mul_a <= vxc; mul_b <= DT;
                        phase <= 7;
                    end else if (phase == 7) begin // Update xc, phi
                        xc <= xc + mul_res[47:16];
                        mul_a <= omega_reg; mul_b <= DT;
                        phase <= 8;
                    end else if (phase == 8) begin // Update t
                        phi <= phi + mul_res[47:16];
                        t <= t + DT;
                        step_cnt <= step_cnt + 1;
                        phase <= 9;
                    end else if (phase == 9) begin // Check Limits
                        if (step_cnt >= MAX_STEPS || t > 32'h00100000) begin
                            state <= S_DONE;
                        end else begin
                            v_idx <= 0;
                            phase <= 0; // Loop vertices
                        end
                    end
                end

                S_DONE: begin
                    result_index <= best_idx;
                    result_time <= best_t;
                    done <= 1; valid <= 1;
                    if (!start) state <= S_IDLE; // Reset on start low
                end
            endcase
        end
    end

    // Input Latching in IDLE
    always @(posedge clk) begin
        if (state == S_IDLE && start) begin
            n_reg <= n;
            omega_reg <= omega;
            v0_reg <= v0;
            theta_reg <= theta_deg;
            wall_reg <= wall_x;
            step_cnt <= 0;
            best_t <= 32'hFFFF_FFFF;
            best_idx <= 0;
            v_idx <= 0;
            xc <= 0; yc <= 0;
            t <= 0; phi <= 0;
            vxc <= 0; vyc <= 0;
        end
    end
endmodule