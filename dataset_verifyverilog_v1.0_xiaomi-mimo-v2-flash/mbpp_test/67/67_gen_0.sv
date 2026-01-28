module BellNumber(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INIT      = 3'd1;
    localparam [2:0] ROW_LOOP  = 3'd2;
    localparam [2:0] COL_LOOP  = 3'd3;
    localparam [2:0] RESULT    = 3'd4;

    // State register
    reg [2:0] state;
    reg [2:0] next_state;

    // Control registers
    reg [3:0] i_reg;          // Row counter (0 to n)
    reg [3:0] j_reg;          // Column counter (0 to i)
    reg [3:0] n_reg;          // Stored input n
    reg start_reg;            // Latched start signal
    reg computation_done;     // Computation completion flag

    // 9x9 triangular storage array (9 rows, each 9 entries)
    // bell[i][j] for i <= 8, j <= 8
    reg [31:0] bell_0 [8:0];  // Row 0
    reg [31:0] bell_1 [8:0];  // Row 1
    reg [31:0] bell_2 [8:0];  // Row 2
    reg [31:0] bell_3 [8:0];  // Row 3
    reg [31:0] bell_4 [8:0];  // Row 4
    reg [31:0] bell_5 [8:0];  // Row 5
    reg [31:0] bell_6 [8:0];  // Row 6
    reg [31:0] bell_7 [8:0];  // Row 7
    reg [31:0] bell_8 [8:0];  // Row 8

    // Cycle counter to prevent infinite loops
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Next state logic (combinational)
    always @(*) begin
        case (state)
            IDLE:       next_state = start_reg ? INIT : IDLE;
            INIT:       next_state = ROW_LOOP;
            ROW_LOOP:   next_state = (i_reg <= n_reg) ? COL_LOOP : RESULT;
            COL_LOOP:   next_state = (j_reg <= i_reg) ? COL_LOOP : ROW_LOOP;
            RESULT:     next_state = IDLE;
            default:    next_state = IDLE;
        endcase
    end

    // State transition and sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            i_reg <= 4'd0;
            j_reg <= 4'd0;
            n_reg <= 4'd0;
            start_reg <= 1'b0;
            computation_done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize Bell table to zero
            begin : init_table
                integer k;
                for (k = 0; k < 9; k = k + 1) begin
                    bell_0[k] <= 32'd0;
                    bell_1[k] <= 32'd0;
                    bell_2[k] <= 32'd0;
                    bell_3[k] <= 32'd0;
                    bell_4[k] <= 32'd0;
                    bell_5[k] <= 32'd0;
                    bell_6[k] <= 32'd0;
                    bell_7[k] <= 32'd0;
                    bell_8[k] <= 32'd0;
                end
            end
        end else begin
            // State transition
            state <= next_state;

            // Pulse done for exactly 1 cycle
            done <= 1'b0;

            case (state)
                IDLE: begin
                    // Latch start pulse
                    if (start) begin
                        start_reg <= 1'b1;
                    end
                    cycle_count <= 8'd0;
                end

                INIT: begin
                    // Store n and initialize bell[0][0] = 1
                    n_reg <= n;
                    start_reg <= 1'b0;
                    bell_0[0] <= 32'd1;
                    i_reg <= 4'd0;
                    j_reg <= 4'd0;
                end

                ROW_LOOP: begin
                    // Move to next row
                    i_reg <= i_reg + 4'd1;
                    j_reg <= 4'd0;
                    cycle_count <= cycle_count + 8'd1;
                end

                COL_LOOP: begin
                    // Compute bell[i][j]
                    if (j_reg == 4'd0) begin
                        // bell[i][0] = bell[i-1][i-1]
                        case (i_reg)
                            4'd1: begin
                                if (i_reg <= 4'd8 && (i_reg-1) <= 4'd8) begin
                                    bell_1[0] <= bell_0[0];
                                end
                            end
                            4'd2: begin
                                if (i_reg <= 4'd8 && (i_reg-1) <= 4'd8) begin
                                    bell_2[0] <= bell_1[1];
                                end
                            end
                            4'd3: begin
                                if (i_reg <= 4'd8 && (i_reg-1) <= 4'd8) begin
                                    bell_3[0] <= bell_2[2];
                                end
                            end
                            4'd4: begin
                                if (i_reg <= 4'd8 && (i_reg-1) <= 4'd8) begin
                                    bell_4[0] <= bell_3[3];
                                end
                            end
                            4'd5: begin
                                if (i_reg <= 4'd8 && (i_reg-1) <= 4'd8) begin
                                    bell_5[0] <= bell_4[4];
                                end
                            end
                            4'd6: begin
                                if (i_reg <= 4'd8 && (i_reg-1) <= 4'd8) begin
                                    bell_6[0] <= bell_5[5];
                                end
                            end
                            4'd7: begin
                                if (i_reg <= 4'd8 && (i_reg-1) <= 4'd8) begin
                                    bell_7[0] <= bell_6[6];
                                end
                            end
                            4'd8: begin
                                if (i_reg <= 4'd8 && (i_reg-1) <= 4'd8) begin
                                    bell_8[0] <= bell_7[7];
                                end
                            end
                            default: begin
                                // Do nothing for invalid i
                            end
                        endcase
                        j_reg <= j_reg + 4'd1;
                    end else begin
                        // bell[i][j] = bell[i-1][j-1] + bell[i][j-1]
                        case (i_reg)
                            4'd1: begin
                                if (j_reg <= 4'd1) begin
                                    bell_1[j_reg] <= bell_0[j_reg-1] + bell_1[j_reg-1];
                                end
                            end
                            4'd2: begin
                                if (j_reg <= 4'd2) begin
                                    bell_2[j_reg] <= bell_1[j_reg-1] + bell_2[j_reg-1];
                                end
                            end
                            4'd3: begin
                                if (j_reg <= 4'd3) begin
                                    bell_3[j_reg] <= bell_2[j_reg-1] + bell_3[j_reg-1];
                                end
                            end
                            4'd4: begin
                                if (j_reg <= 4'd4) begin
                                    bell_4[j_reg] <= bell_3[j_reg-1] + bell_4[j_reg-1];
                                end
                            end
                            4'd5: begin
                                if (j_reg <= 4'd5) begin
                                    bell_5[j_reg] <= bell_4[j_reg-1] + bell_5[j_reg-1];
                                end
                            end
                            4'd6: begin
                                if (j_reg <= 4'd6) begin
                                    bell_6[j_reg] <= bell_5[j_reg-1] + bell_6[j_reg-1];
                                end
                            end
                            4'd7: begin
                                if (j_reg <= 4'd7) begin
                                    bell_7[j_reg] <= bell_6[j_reg-1] + bell_7[j_reg-1];
                                end
                            end
                            4'd8: begin
                                if (j_reg <= 4'd8) begin
                                    bell_8[j_reg] <= bell_7[j_reg-1] + bell_8[j_reg-1];
                                end
                            end
                            default: begin
                                // Do nothing for invalid i
                            end
                        endcase
                        j_reg <= j_reg + 4'd1;
                    end
                    cycle_count <= cycle_count + 8'd1;
                end

                RESULT: begin
                    // Output bell[n][0] and pulse done
                    case (n_reg)
                        4'd0: result <= bell_0[0];
                        4'd1: result <= bell_1[0];
                        4'd2: result <= bell_2[0];
                        4'd3: result <= bell_3[0];
                        4'd4: result <= bell_4[0];
                        4'd5: result <= bell_5[0];
                        4'd6: result <= bell_6[0];
                        4'd7: result <= bell_7[0];
                        4'd8: result <= bell_8[0];
                        default: result <= 32'd0;
                    endcase
                    done <= 1'b1;
                    computation_done <= 1'b1;
                end

                default: begin
                    state <= IDLE;
                end
            endcase

            // Safety check: timeout
            if (cycle_count >= MAX_CYCLES && state != IDLE) begin
                state <= IDLE;
                done <= 1'b0;
                start_reg <= 1'b0;
            end
        end
    end

endmodule