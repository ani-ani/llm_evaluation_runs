module BacteriaSimulation (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] trap_row,
    input wire [7:0] trap_col,
    // Bacterium 0 inputs
    input wire [7:0] start_row_0,
    input wire [7:0] start_col_0,
    input wire [1:0] start_dir_0,
    input wire [31:0] grid_0_0, input wire [31:0] grid_0_1,
    input wire [31:0] grid_0_2, input wire [31:0] grid_0_3,
    input wire [31:0] grid_0_4, input wire [31:0] grid_0_5,
    input wire [31:0] grid_0_6, input wire [31:0] grid_0_7,
    // Bacterium 1 inputs
    input wire [7:0] start_row_1,
    input wire [7:0] start_col_1,
    input wire [1:0] start_dir_1,
    input wire [31:0] grid_1_0, input wire [31:0] grid_1_1,
    input wire [31:0] grid_1_2, input wire [31:0] grid_1_3,
    input wire [31:0] grid_1_4, input wire [31:0] grid_1_5,
    input wire [31:0] grid_1_6, input wire [31:0] grid_1_7,
    // Outputs
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] INIT     = 3'd1;
    localparam [2:0] CHECK    = 3'd2;
    localparam [2:0] UPDATE   = 3'd3;
    localparam [2:0] FINISH   = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [15:0] time_step;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd250;
    localparam [15:0] TIMEOUT = 16'd65535;

    // Bacterium 0 state
    reg [7:0] row_0, col_0;
    reg [1:0] dir_0;
    reg found_0;

    // Bacterium 1 state
    reg [7:0] row_1, col_1;
    reg [1:0] dir_1;
    reg found_1;

    // Grid values (4-bit per cell)
    reg [3:0] grid_0_val;
    reg [3:0] grid_1_val;

    // Helper signals for grid access
    wire [3:0] g0_0_0 = grid_0_0[3:0];
    wire [3:0] g0_0_1 = grid_0_0[7:4];
    wire [3:0] g0_0_2 = grid_0_0[11:8];
    wire [3:0] g0_0_3 = grid_0_0[15:12];
    wire [3:0] g0_0_4 = grid_0_0[19:16];
    wire [3:0] g0_0_5 = grid_0_0[23:20];
    wire [3:0] g0_0_6 = grid_0_0[27:24];
    wire [3:0] g0_0_7 = grid_0_0[31:28];

    wire [3:0] g0_1_0 = grid_0_1[3:0];
    wire [3:0] g0_1_1 = grid_0_1[7:4];
    wire [3:0] g0_1_2 = grid_0_1[11:8];
    wire [3:0] g0_1_3 = grid_0_1[15:12];
    wire [3:0] g0_1_4 = grid_0_1[19:16];
    wire [3:0] g0_1_5 = grid_0_1[23:20];
    wire [3:0] g0_1_6 = grid_0_1[27:24];
    wire [3:0] g0_1_7 = grid_0_1[31:28];

    wire [3:0] g0_2_0 = grid_0_2[3:0];
    wire [3:0] g0_2_1 = grid_0_2[7:4];
    wire [3:0] g0_2_2 = grid_0_2[11:8];
    wire [3:0] g0_2_3 = grid_0_2[15:12];
    wire [3:0] g0_2_4 = grid_0_2[19:16];
    wire [3:0] g0_2_5 = grid_0_2[23:20];
    wire [3:0] g0_2_6 = grid_0_2[27:24];
    wire [3:0] g0_2_7 = grid_0_2[31:28];

    wire [3:0] g0_3_0 = grid_0_3[3:0];
    wire [3:0] g0_3_1 = grid_0_3[7:4];
    wire [3:0] g0_3_2 = grid_0_3[11:8];
    wire [3:0] g0_3_3 = grid_0_3[15:12];
    wire [3:0] g0_3_4 = grid_0_3[19:16];
    wire [3:0] g0_3_5 = grid_0_3[23:20];
    wire [3:0] g0_3_6 = grid_0_3[27:24];
    wire [3:0] g0_3_7 = grid_0_3[31:28];

    wire [3:0] g0_4_0 = grid_0_4[3:0];
    wire [3:0] g0_4_1 = grid_0_4[7:4];
    wire [3:0] g0_4_2 = grid_0_4[11:8];
    wire [3:0] g0_4_3 = grid_0_4[15:12];
    wire [3:0] g0_4_4 = grid_0_4[19:16];
    wire [3:0] g0_4_5 = grid_0_4[23:20];
    wire [3:0] g0_4_6 = grid_0_4[27:24];
    wire [3:0] g0_4_7 = grid_0_4[31:28];

    wire [3:0] g0_5_0 = grid_0_5[3:0];
    wire [3:0] g0_5_1 = grid_0_5[7:4];
    wire [3:0] g0_5_2 = grid_0_5[11:8];
    wire [3:0] g0_5_3 = grid_0_5[15:12];
    wire [3:0] g0_5_4 = grid_0_5[19:16];
    wire [3:0] g0_5_5 = grid_0_5[23:20];
    wire [3:0] g0_5_6 = grid_0_5[27:24];
    wire [3:0] g0_5_7 = grid_0_5[31:28];

    wire [3:0] g0_6_0 = grid_0_6[3:0];
    wire [3:0] g0_6_1 = grid_0_6[7:4];
    wire [3:0] g0_6_2 = grid_0_6[11:8];
    wire [3:0] g0_6_3 = grid_0_6[15:12];
    wire [3:0] g0_6_4 = grid_0_6[19:16];
    wire [3:0] g0_6_5 = grid_0_6[23:20];
    wire [3:0] g0_6_6 = grid_0_6[27:24];
    wire [3:0] g0_6_7 = grid_0_6[31:28];

    wire [3:0] g0_7_0 = grid_0_7[3:0];
    wire [3:0] g0_7_1 = grid_0_7[7:4];
    wire [3:0] g0_7_2 = grid_0_7[11:8];
    wire [3:0] g0_7_3 = grid_0_7[15:12];
    wire [3:0] g0_7_4 = grid_0_7[19:16];
    wire [3:0] g0_7_5 = grid_0_7[23:20];
    wire [3:0] g0_7_6 = grid_0_7[27:24];
    wire [3:0] g0_7_7 = grid_0_7[31:28];

    wire [3:0] g1_0_0 = grid_1_0[3:0];
    wire [3:0] g1_0_1 = grid_1_0[7:4];
    wire [3:0] g1_0_2 = grid_1_0[11:8];
    wire [3:0] g1_0_3 = grid_1_0[15:12];
    wire [3:0] g1_0_4 = grid_1_0[19:16];
    wire [3:0] g1_0_5 = grid_1_0[23:20];
    wire [3:0] g1_0_6 = grid_1_0[27:24];
    wire [3:0] g1_0_7 = grid_1_0[31:28];

    wire [3:0] g1_1_0 = grid_1_1[3:0];
    wire [3:0] g1_1_1 = grid_1_1[7:4];
    wire [3:0] g1_1_2 = grid_1_1[11:8];
    wire [3:0] g1_1_3 = grid_1_1[15:12];
    wire [3:0] g1_1_4 = grid_1_1[19:16];
    wire [3:0] g1_1_5 = grid_1_1[23:20];
    wire [3:0] g1_1_6 = grid_1_1[27:24];
    wire [3:0] g1_1_7 = grid_1_1[31:28];

    wire [3:0] g1_2_0 = grid_1_2[3:0];
    wire [3:0] g1_2_1 = grid_1_2[7:4];
    wire [3:0] g1_2_2 = grid_1_2[11:8];
    wire [3:0] g1_2_3 = grid_1_2[15:12];
    wire [3:0] g1_2_4 = grid_1_2[19:16];
    wire [3:0] g1_2_5 = grid_1_2[23:20];
    wire [3:0] g1_2_6 = grid_1_2[27:24];
    wire [3:0] g1_2_7 = grid_1_2[31:28];

    wire [3:0] g1_3_0 = grid_1_3[3:0];
    wire [3:0] g1_3_1 = grid_1_3[7:4];
    wire [3:0] g1_3_2 = grid_1_3[11:8];
    wire [3:0] g1_3_3 = grid_1_3[15:12];
    wire [3:0] g1_3_4 = grid_1_3[19:16];
    wire [3:0] g1_3_5 = grid_1_3[23:20];
    wire [3:0] g1_3_6 = grid_1_3[27:24];
    wire [3:0] g1_3_7 = grid_1_3[31:28];

    wire [3:0] g1_4_0 = grid_1_4[3:0];
    wire [3:0] g1_4_1 = grid_1_4[7:4];
    wire [3:0] g1_4_2 = grid_1_4[11:8];
    wire [3:0] g1_4_3 = grid_1_4[15:12];
    wire [3:0] g1_4_4 = grid_1_4[19:16];
    wire [3:0] g1_4_5 = grid_1_4[23:20];
    wire [3:0] g1_4_6 = grid_1_4[27:24];
    wire [3:0] g1_4_7 = grid_1_4[31:28];

    wire [3:0] g1_5_0 = grid_1_5[3:0];
    wire [3:0] g1_5_1 = grid_1_5[7:4];
    wire [3:0] g1_5_2 = grid_1_5[11:8];
    wire [3:0] g1_5_3 = grid_1_5[15:12];
    wire [3:0] g1_5_4 = grid_1_5[19:16];
    wire [3:0] g1_5_5 = grid_1_5[23:20];
    wire [3:0] g1_5_6 = grid_1_5[27:24];
    wire [3:0] g1_5_7 = grid_1_5[31:28];

    wire [3:0] g1_6_0 = grid_1_6[3:0];
    wire [3:0] g1_6_1 = grid_1_6[7:4];
    wire [3:0] g1_6_2 = grid_1_6[11:8];
    wire [3:0] g1_6_3 = grid_1_6[15:12];
    wire [3:0] g1_6_4 = grid_1_6[19:16];
    wire [3:0] g1_6_5 = grid_1_6[23:20];
    wire [3:0] g1_6_6 = grid_1_6[27:24];
    wire [3:0] g1_6_7 = grid_1_6[31:28];

    wire [3:0] g1_7_0 = grid_1_7[3:0];
    wire [3:0] g1_7_1 = grid_1_7[7:4];
    wire [3:0] g1_7_2 = grid_1_7[11:8];
    wire [3:0] g1_7_3 = grid_1_7[15:12];
    wire [3:0] g1_7_4 = grid_1_7[19:16];
    wire [3:0] g1_7_5 = grid_1_7[23:20];
    wire [3:0] g1_7_6 = grid_1_7[27:24];
    wire [3:0] g1_7_7 = grid_1_7[31:28];

    // Grid value lookup logic for each bacterium
    always @(*) begin
        // Bacterium 0 grid lookup
        case (row_0)
            8'd1: grid_0_val = (col_0 == 8'd1) ? g0_0_0 : (col_0 == 8'd2) ? g0_0_1 : (col_0 == 8'd3) ? g0_0_2 : (col_0 == 8'd4) ? g0_0_3 : (col_0 == 8'd5) ? g0_0_4 : (col_0 == 8'd6) ? g0_0_5 : (col_0 == 8'd7) ? g0_0_6 : g0_0_7;
            8'd2: grid_0_val = (col_0 == 8'd1) ? g0_1_0 : (col_0 == 8'd2) ? g0_1_1 : (col_0 == 8'd3) ? g0_1_2 : (col_0 == 8'd4) ? g0_1_3 : (col_0 == 8'd5) ? g0_1_4 : (col_0 == 8'd6) ? g0_1_5 : (col_0 == 8'd7) ? g0_1_6 : g0_1_7;
            8'd3: grid_0_val = (col_0 == 8'd1) ? g0_2_0 : (col_0 == 8'd2) ? g0_2_1 : (col_0 == 8'd3) ? g0_2_2 : (col_0 == 8'd4) ? g0_2_3 : (col_0 == 8'd5) ? g0_2_4 : (col_0 == 8'd6) ? g0_2_5 : (col_0 == 8'd7) ? g0_2_6 : g0_2_7;
            8'd4: grid_0_val = (col_0 == 8'd1) ? g0_3_0 : (col_0 == 8'd2) ? g0_3_1 : (col_0 == 8'd3) ? g0_3_2 : (col_0 == 8'd4) ? g0_3_3 : (col_0 == 8'd5) ? g0_3_4 : (col_0 == 8'd6) ? g0_3_5 : (col_0 == 8'd7) ? g0_3_6 : g0_3_7;
            8'd5: grid_0_val = (col_0 == 8'd1) ? g0_4_0 : (col_0 == 8'd2) ? g0_4_1 : (col_0 == 8'd3) ? g0_4_2 : (col_0 == 8'd4) ? g0_4_3 : (col_0 == 8'd5) ? g0_4_4 : (col_0 == 8'd6) ? g0_4_5 : (col_0 == 8'd7) ? g0_4_6 : g0_4_7;
            8'd6: grid_0_val = (col_0 == 8'd1) ? g0_5_0 : (col_0 == 8'd2) ? g0_5_1 : (col_0 == 8'd3) ? g0_5_2 : (col_0 == 8'd4) ? g0_5_3 : (col_0 == 8'd5) ? g0_5_4 : (col_0 == 8'd6) ? g0_5_5 : (col_0 == 8'd7) ? g0_5_6 : g0_5_7;
            8'd7: grid_0_val = (col_0 == 8'd1) ? g0_6_0 : (col_0 == 8'd2) ? g0_6_1 : (col_0 == 8'd3) ? g0_6_2 : (col_0 == 8'd4) ? g0_6_3 : (col_0 == 8'd5) ? g0_6_4 : (col_0 == 8'd6) ? g0_6_5 : (col_0 == 8'd7) ? g0_6_6 : g0_6_7;
            8'd8: grid_0_val = (col_0 == 8'd1) ? g0_7_0 : (col_0 == 8'd2) ? g0_7_1 : (col_0 == 8'd3) ? g0_7_2 : (col_0 == 8'd4) ? g0_7_3 : (col_0 == 8'd5) ? g0_7_4 : (col_0 == 8'd6) ? g0_7_5 : (col_0 == 8'd7) ? g0_7_6 : g0_7_7;
            default: grid_0_val = 4'd0;
        endcase

        // Bacterium 1 grid lookup
        case (row_1)
            8'd1: grid_1_val = (col_1 == 8'd1) ? g1_0_0 : (col_1 == 8'd2) ? g1_0_1 : (col_1 == 8'd3) ? g1_0_2 : (col_1 == 8'd4) ? g1_0_3 : (col_1 == 8'd5) ? g1_0_4 : (col_1 == 8'd6) ? g1_0_5 : (col_1 == 8'd7) ? g1_0_6 : g1_0_7;
            8'd2: grid_1_val = (col_1 == 8'd1) ? g1_1_0 : (col_1 == 8'd2) ? g1_1_1 : (col_1 == 8'd3) ? g1_1_2 : (col_1 == 8'd4) ? g1_1_3 : (col_1 == 8'd5) ? g1_1_4 : (col_1 == 8'd6) ? g1_1_5 : (col_1 == 8'd7) ? g1_1_6 : g1_1_7;
            8'd3: grid_1_val = (col_1 == 8'd1) ? g1_2_0 : (col_1 == 8'd2) ? g1_2_1 : (col_1 == 8'd3) ? g1_2_2 : (col_1 == 8'd4) ? g1_2_3 : (col_1 == 8'd5) ? g1_2_4 : (col_1 == 8'd6) ? g1_2_5 : (col_1 == 8'd7) ? g1_2_6 : g1_2_7;
            8'd4: grid_1_val = (col_1 == 8'd1) ? g1_3_0 : (col_1 == 8'd2) ? g1_3_1 : (col_1 == 8'd3) ? g1_3_2 : (col_1 == 8'd4) ? g1_3_3 : (col_1 == 8'd5) ? g1_3_4 : (col_1 == 8'd6) ? g1_3_5 : (col_1 == 8'd7) ? g1_3_6 : g1_3_7;
            8'd5: grid_1_val = (col_1 == 8'd1) ? g1_4_0 : (col_1 == 8'd2) ? g1_4_1 : (col_1 == 8'd3) ? g1_4_2 : (col_1 == 8'd4) ? g1_4_3 : (col_1 == 8'd5) ? g1_4_4 : (col_1 == 8'd6) ? g1_4_5 : (col_1 == 8'd7) ? g1_4_6 : g1_4_7;
            8'd6: grid_1_val = (col_1 == 8'd1) ? g1_5_0 : (col_1 == 8'd2) ? g1_5_1 : (col_1 == 8'd3) ? g1_5_2 : (col_1 == 8'd4) ? g1_5_3 : (col_1 == 8'd5) ? g1_5_4 : (col_1 == 8'd6) ? g1_5_5 : (col_1 == 8'd7) ? g1_5_6 : g1_5_7;
            8'd7: grid_1_val = (col_1 == 8'd1) ? g1_6_0 : (col_1 == 8'd2) ? g1_6_1 : (col_1 == 8'd3) ? g1_6_2 : (col_1 == 8'd4) ? g1_6_3 : (col_1 == 8'd5) ? g1_6_4 : (col_1 == 8'd6) ? g1_6_5 : (col_1 == 8'd7) ? g1_6_6 : g1_6_7;
            8'd8: grid_1_val = (col_1 == 8'd1) ? g1_7_0 : (col_1 == 8'd2) ? g1_7_1 : (col_1 == 8'd3) ? g1_7_2 : (col_1 == 8'd4) ? g1_7_3 : (col_1 == 8'd5) ? g1_7_4 : (col_1 == 8'd6) ? g1_7_5 : (col_1 == 8'd7) ? g1_7_6 : g1_7_7;
            default: grid_1_val = 4'd0;
        endcase
    end

    // Next state logic
    always @(*) begin
        next_state = IDLE;
        case (state)
            IDLE: next_state = (start) ? INIT : IDLE;
            INIT: next_state = CHECK;
            CHECK: begin
                if (found_0 && found_1) begin
                    next_state = FINISH;
                end else begin
                    next_state = UPDATE;
                end
            end
            UPDATE: begin
                if (time_step >= 16'd255) begin
                    next_state = FINISH;
                end else begin
                    next_state = CHECK;
                end
            end
            FINISH: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            time_step <= 16'd0;
            cycle_count <= 8'd0;
            row_0 <= 8'd0;
            col_0 <= 8'd0;
            dir_0 <= 2'd0;
            found_0 <= 1'b0;
            row_1 <= 8'd0;
            col_1 <= 8'd0;
            dir_1 <= 2'd0;
            found_1 <= 1'b0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                end
                INIT: begin
                    time_step <= 16'd0;
                    // Initialize bacterium 0
                    row_0 <= start_row_0;
                    col_0 <= start_col_0;
                    dir_0 <= start_dir_0;
                    found_0 <= (start_row_0 == trap_row && start_col_0 == trap_col) ? 1'b1 : 1'b0;
                    // Initialize bacterium 1
                    row_1 <= start_row_1;
                    col_1 <= start_col_1;
                    dir_1 <= start_dir_1;
                    found_1 <= (start_row_1 == trap_row && start_col_1 == trap_col) ? 1'b1 : 1'b0;
                end
                CHECK: begin
                    // Check if both at trap
                    if (found_0 && found_1) begin
                        result <= time_step;
                    end
                end
                UPDATE: begin
                    cycle_count <= cycle_count + 8'd1;
                    time_step <= time_step + 16'd1;
                    // Update bacterium 0
                    if (!found_0) begin
                        if (grid_0_val < 4'd4) begin
                            dir_0 <= dir_0 + 2'd1;
                        end
                        if (grid_0_val < 4'd8) begin
                            dir_0 <= dir_0 + 2'd1;
                        end
                        // Move based on direction
                        case (dir_0)
                            2'd0: begin // Up
                                if (row_0 > 8'd1) row_0 <= row_0 - 8'd1;
                            end
                            2'd1: begin // Right
                                if (col_0 < 8'd8) col_0 <= col_0 + 8'd1;
                            end
                            2'd2: begin // Down
                                if (row_0 < 8'd8) row_0 <= row_0 + 8'd1;
                            end
                            2'd3: begin // Left
                                if (col_0 > 8'd1) col_0 <= col_0 - 8'd1;
                            end
                        endcase
                        // Check after move
                        if (row_0 == trap_row && col_0 == trap_col) begin
                            found_0 <= 1'b1;
                        end
                    end

                    // Update bacterium 1
                    if (!found_1) begin
                        if (grid_1_val < 4'd4) begin
                            dir_1 <= dir_1 + 2'd1;
                        end
                        if (grid_1_val < 4'd8) begin
                            dir_1 <= dir_1 + 2'd1;
                        end
                        // Move based on direction
                        case (dir_1)
                            2'd0: begin // Up
                                if (row_1 > 8'd1) row_1 <= row_1 - 8'd1;
                            end
                            2'd1: begin // Right
                                if (col_1 < 8'd8) col_1 <= col_1 + 8'd1;
                            end
                            2'd2: begin // Down
                                if (row_1 < 8'd8) row_1 <= row_1 + 8'd1;
                            end
                            2'd3: begin // Left
                                if (col_1 > 8'd1) col_1 <= col_1 - 8'd1;
                            end
                        endcase
                        // Check after move
                        if (row_1 == trap_row && col_1 == trap_col) begin
                            found_1 <= 1'b1;
                        end
                    end
                    // Timeout check
                    if (cycle_count >= MAX_CYCLES) begin
                        result <= TIMEOUT;
                    end
                end
                FINISH: begin
                    done <= 1'b1;
                    // If result not set yet (timeout case)
                    if (!found_0 || !found_1) begin
                        result <= TIMEOUT;
                    end
                end
                default: begin
                    state <= IDLE;
                    result <= 16'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule