module maximum_gnome_damage(
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    input [3:0] m,
    input [7:0] k,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] t_reg;
    reg [7:0] T_reg;
    reg [7:0] R_reg;
    reg [15:0] D1_reg;
    reg [15:0] D2_reg;
    reg [15:0] damage_reg;
    reg [15:0] best_damage;
    reg [7:0] a_reg;
    reg [7:0] b_reg;
    reg [7:0] L1_reg;
    reg [7:0] U1_reg;
    reg [7:0] L2_reg;
    reg [7:0] L_reg;
    reg [7:0] U_reg;
    reg [7:0] cycle_count;
    reg [7:0] inner_cycle_count;
    reg [7:0] temp_reg;
    reg [7:0] i_reg;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            t_reg <= 8'd0;
            T_reg <= 8'd0;
            R_reg <= 8'd0;
            D1_reg <= 16'd0;
            D2_reg <= 16'd0;
            damage_reg <= 16'd0;
            best_damage <= 16'd0;
            a_reg <= 8'd0;
            b_reg <= 8'd0;
            L1_reg <= 8'd0;
            U1_reg <= 8'd0;
            L2_reg <= 8'd0;
            L_reg <= 8'd0;
            U_reg <= 8'd0;
            cycle_count <= 8'd0;
            inner_cycle_count <= 8'd0;
            temp_reg <= 8'd0;
            i_reg <= 8'd0;
            result <= 16'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                end else begin
                    next_state = IDLE;
                end
            end

            INIT: begin
                if (n <= m) begin
                    next_state = FINISH;
                end else begin
                    next_state = COMPUTE;
                end
            end

            COMPUTE: begin
                if (cycle_count >= 8'd1000) begin
                    next_state = FINISH;
                end else begin
                    next_state = COMPUTE;
                end
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled in state machine
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                end

                INIT: begin
                    if (n <= m) begin
                        best_damage <= n * (n + 8'd1) / 8'd2;
                    end else begin
                        t_reg <= m;
                        cycle_count <= 8'd0;
                        best_damage <= 16'd0;
                    end
                end

                COMPUTE: begin
                    // Compute L1 = ceil((n - t*(k-1))/k)
                    temp_reg <= t_reg * (k - 8'd1);
                    if (n > temp_reg) begin
                        L1_reg <= (n - temp_reg + k - 8'd1) / k;
                    end else begin
                        L1_reg <= 8'd0;
                    end

                    // Compute U1 = floor((n - t)/k)
                    if (n > t_reg) begin
                        U1_reg <= (n - t_reg) / k;
                    end else begin
                        U1_reg <= 8'd0;
                    end

                    // Compute L2 = m - t
                    L2_reg <= m - t_reg;

                    // L = max(L1, L2)
                    if (L1_reg > L2_reg) begin
                        L_reg <= L1_reg;
                    end else begin
                        L_reg <= L2_reg;
                    end

                    // U = U1
                    U_reg <= U1_reg;

                    // Check if L <= U
                    if (L_reg <= U_reg) begin
                        // Initialize T to L
                        if (cycle_count == 8'd0) begin
                            T_reg <= L_reg;
                            inner_cycle_count <= 8'd0;
                        end else begin
                            // Iterate T from L to U
                            if (inner_cycle_count == 8'd0) begin
                                T_reg <= L_reg;
                            end else if (inner_cycle_count == 8'd1) begin
                                T_reg <= U_reg;
                            end

                            // Compute R = n - k*T
                            R_reg <= n - k * T_reg;

                            // Compute D1 = n*T - k*T*(T-1)/2
                            D1_reg <= n * T_reg - k * T_reg * (T_reg - 8'd1) / 8'd2;

                            // Compute D2
                            if (t_reg > 8'd0) begin
                                a_reg <= R_reg / t_reg;
                                b_reg <= R_reg % t_reg;
                                D2_reg <= a_reg * t_reg * (t_reg + 8'd1) / 8'd2 + b_reg * (b_reg + 8'd1) / 8'd2;
                            end else begin
                                D2_reg <= 16'd0;
                            end

                            // Compute damage = D1 + D2
                            damage_reg <= D1_reg + D2_reg;

                            // Update best damage
                            if (damage_reg > best_damage) begin
                                best_damage <= damage_reg;
                            end

                            // Increment inner cycle count
                            if (inner_cycle_count == 8'd1) begin
                                inner_cycle_count <= 8'd0;
                                t_reg <= t_reg - 8'd1;
                            end else begin
                                inner_cycle_count <= inner_cycle_count + 8'd1;
                            end
                        end

                        // Increment cycle count
                        cycle_count <= cycle_count + 8'd1;

                        // Check if done with all t values
                        if (t_reg == 8'd0) begin
                            next_state = FINISH;
                        end
                    end else begin
                        // Move to next t
                        t_reg <= t_reg - 8'd1;
                        cycle_count <= cycle_count + 8'd1;

                        if (t_reg == 8'd0) begin
                            next_state = FINISH;
                        end
                    end
                end

                FINISH: begin
                    result <= best_damage;
                    done <= 1'b1;
                end

                default: begin
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule