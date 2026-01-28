module mst_calculator (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire [31:0] x0, y0, z0,
    input wire [31:0] x1, y1, z1,
    input wire [31:0] x2, y2, z2,
    input wire [31:0] x3, y3, z3,
    input wire [31:0] x4, y4, z4,
    input wire [31:0] x5, y5, z5,
    input wire [31:0] x6, y6, z6,
    input wire [31:0] x7, y7, z7,
    output reg [31:0] result,
    output reg done
);

    localparam MAX_N = 8;
    localparam DATA_WIDTH = 32;
    localparam INF = 32'h7FFF_FFFF;

    // State definitions
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] INIT_DIST = 4'd1;
    localparam [3:0] FIND_MIN = 4'd2;
    localparam [3:0] ADD_TO_TREE = 4'd3;
    localparam [3:0] UPDATE_DIST = 4'd4;
    localparam [3:0] DONE = 4'd5;
    localparam [3:0] COST_WAIT = 4'd6;

    // Registers for coordinates
    reg [DATA_WIDTH-1:0] x_reg [0:MAX_N-1];
    reg [DATA_WIDTH-1:0] y_reg [0:MAX_N-1];
    reg [DATA_WIDTH-1:0] z_reg [0:MAX_N-1];
    reg loaded;

    // State machine registers
    reg [3:0] state;
    reg [MAX_N-1:0] visited;
    reg [DATA_WIDTH-1:0] dist [0:MAX_N-1];
    reg [DATA_WIDTH-1:0] total_cost;
    reg [3:0] curr_planet;
    reg [3:0] visited_count;
    reg [3:0] idx;
    reg [3:0] init_i;
    reg [3:0] find_j;
    reg [3:0] update_k;
    reg [1:0] entry_flag;

    // Cost computation interface
    reg cost_compute_start;
    reg [3:0] i_idx;
    reg [3:0] j_idx;
    reg [DATA_WIDTH-1:0] cost_out;
    reg cost_valid;

    // Cost computation unit state
    reg [1:0] cost_state;
    reg [DATA_WIDTH-1:0] temp_x_i, temp_y_i, temp_z_i;
    reg [DATA_WIDTH-1:0] temp_x_j, temp_y_j, temp_z_j;
    reg [DATA_WIDTH-1:0] temp_dx, temp_dy, temp_dz;
    reg [DATA_WIDTH-1:0] abs_dx, abs_dy, abs_dz;

    // Helper: latch coordinates on start
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            loaded <= 1'b0;
        end else if (start) begin
            x_reg[0] <= x0; y_reg[0] <= y0; z_reg[0] <= z0;
            x_reg[1] <= x1; y_reg[1] <= y1; z_reg[1] <= z1;
            x_reg[2] <= x2; y_reg[2] <= y2; z_reg[2] <= z2;
            x_reg[3] <= x3; y_reg[3] <= y3; z_reg[3] <= z3;
            x_reg[4] <= x4; y_reg[4] <= y4; z_reg[4] <= z4;
            x_reg[5] <= x5; y_reg[5] <= y5; z_reg[5] <= z5;
            x_reg[6] <= x6; y_reg[6] <= y6; z_reg[6] <= z6;
            x_reg[7] <= x7; y_reg[7] <= y7; z_reg[7] <= z7;
            loaded <= 1'b1;
        end
    end

    // Cost computation unit (sequential, 4 cycles)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cost_state <= 2'b00;
            cost_valid <= 1'b0;
            cost_out <= 32'd0;
        end else begin
            case (cost_state)
                2'b00: begin
                    cost_valid <= 1'b0;
                    if (cost_compute_start) begin
                        temp_x_i <= x_reg[i_idx];
                        temp_y_i <= y_reg[i_idx];
                        temp_z_i <= z_reg[i_idx];
                        temp_x_j <= x_reg[j_idx];
                        temp_y_j <= y_reg[j_idx];
                        temp_z_j <= z_reg[j_idx];
                        cost_state <= 2'b01;
                    end
                end
                2'b01: begin
                    temp_dx <= temp_x_i - temp_x_j;
                    temp_dy <= temp_y_i - temp_y_j;
                    temp_dz <= temp_z_i - temp_z_j;
                    cost_state <= 2'b10;
                end
                2'b10: begin
                    abs_dx <= (temp_dx[31]) ? -temp_dx : temp_dx;
                    abs_dy <= (temp_dy[31]) ? -temp_dy : temp_dy;
                    abs_dz <= (temp_dz[31]) ? -temp_dz : temp_dz;
                    cost_state <= 2'b11;
                end
                2'b11: begin
                    if (abs_dx < abs_dy) begin
                        if (abs_dx < abs_dz) begin
                            cost_out <= abs_dx;
                        end else begin
                            cost_out <= abs_dz;
                        end
                    end else begin
                        if (abs_dy < abs_dz) begin
                            cost_out <= abs_dy;
                        end else begin
                            cost_out <= abs_dz;
                        end
                    end
                    cost_valid <= 1'b1;
                    cost_state <= 2'b00;
                end
            endcase
        end
    end

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            visited <= 8'd0;
            total_cost <= 32'd0;
            curr_planet <= 4'd0;
            visited_count <= 4'd0;
            idx <= 4'd0;
            init_i <= 4'd0;
            find_j <= 4'd0;
            update_k <= 4'd0;
            cost_compute_start <= 1'b0;
            cost_out <= 32'd0;
            cost_valid <= 1'b0;
            entry_flag <= 2'b00;
            result <= 32'd0;
            done <= 1'b0;
            for (integer i = 0; i < MAX_N; i = i + 1) begin
                dist[i] <= INF;
            end
        end else begin
            // Default assignments
            cost_compute_start <= 1'b0;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start && loaded) begin
                        for (integer i = 0; i < MAX_N; i = i + 1) begin
                            dist[i] <= INF;
                        end
                        visited <= 8'd0;
                        total_cost <= 32'd0;
                        visited_count <= 4'd0;
                        init_i <= 4'd1;
                        if (N == 4'd1) begin
                            state <= DONE;
                        end else begin
                            state <= INIT_DIST;
                        end
                    end
                end

                INIT_DIST: begin
                    i_idx <= 4'd0;
                    j_idx <= init_i;
                    cost_compute_start <= 1'b1;
                    entry_flag <= 2'b01;
                    state <= COST_WAIT;
                end

                FIND_MIN: begin
                    if (find_j < N) begin
                        if (!visited[find_j] && (dist[find_j] < total_cost)) begin
                            total_cost <= dist[find_j];
                            curr_planet <= find_j;
                        end
                        find_j <= find_j + 4'd1;
                    end else begin
                        find_j <= 4'd0;
                        state <= ADD_TO_TREE;
                    end
                end

                ADD_TO_TREE: begin
                    visited[curr_planet] <= 1'b1;
                    visited_count <= visited_count + 4'd1;
                    state <= UPDATE_DIST;
                    update_k <= 4'd0;
                end

                UPDATE_DIST: begin
                    if (update_k < N) begin
                        if (!visited[update_k]) begin
                            i_idx <= curr_planet;
                            j_idx <= update_k;
                            cost_compute_start <= 1'b1;
                            entry_flag <= 2'b10;
                            state <= COST_WAIT;
                        end else begin
                            update_k <= update_k + 4'd1;
                        end
                    end else begin
                        if (visited_count == N - 4'd1) begin
                            state <= DONE;
                        end else begin
                            state <= FIND_MIN;
                            total_cost <= INF;
                            find_j <= 4'd0;
                        end
                    end
                end

                COST_WAIT: begin
                    if (cost_valid) begin
                        if (entry_flag == 2'b01) begin
                            dist[init_i] <= cost_out;
                            if (init_i + 4'd1 < N) begin
                                init_i <= init_i + 4'd1;
                                state <= INIT_DIST;
                            end else begin
                                init_i <= 4'd0;
                                state <= FIND_MIN;
                                total_cost <= INF;
                                find_j <= 4'd0;
                            end
                        end else if (entry_flag == 2'b10) begin
                            if (cost_out < dist[update_k]) begin
                                dist[update_k] <= cost_out;
                            end
                            update_k <= update_k + 4'd1;
                            state <= UPDATE_DIST;
                        end
                    end
                end

                DONE: begin
                    result <= total_cost;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule