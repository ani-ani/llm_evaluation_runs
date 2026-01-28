module BellNumber(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] INIT     = 3'd1;
    localparam [2:0] ROW_LOOP = 3'd2;
    localparam [2:0] COL_LOOP = 3'd3;
    localparam [2:0] RESULT   = 3'd4;

    // Register declarations
    reg [2:0] state;
    reg [3:0] i_reg;
    reg [3:0] j_reg;
    reg start_reg;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Bell number storage (9x9 x 32-bit)
    reg [31:0] bell [0:8][0:8];

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i_reg <= 4'd0;
            j_reg <= 4'd0;
            start_reg <= 1'b0;
            cycle_count <= 8'd0;
            result <= 32'd0;
            done <= 1'b0;

            // Initialize bell array
            integer i, j;
            for (i = 0; i < 9; i = i + 1) begin
                for (j = 0; j < 9; j = j + 1) begin
                    bell[i][j] <= 32'd0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        start_reg <= 1'b1;
                        state <= INIT;
                    end
                end

                INIT: begin
                    // Initialize bell[0][0] = 1
                    bell[0][0] <= 32'd1;
                    i_reg <= 4'd1;
                    state <= ROW_LOOP;
                end

                ROW_LOOP: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (i_reg <= n) begin
                        j_reg <= 4'd1;
                        state <= COL_LOOP;
                    end else begin
                        state <= RESULT;
                    end
                end

                COL_LOOP: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (j_reg <= i_reg) begin
                        if (j_reg == 1) begin
                            // bell[i][0] = bell[i-1][i-1]
                            bell[i_reg][0] <= bell[i_reg - 1][i_reg - 1];
                        end else begin
                            // bell[i][j] = bell[i-1][j-1] + bell[i][j-1]
                            bell[i_reg][j_reg] <= bell[i_reg - 1][j_reg - 1] + bell[i_reg][j_reg - 1];
                        end
                        j_reg <= j_reg + 4'd1;
                    end else begin
                        i_reg <= i_reg + 4'd1;
                        state <= ROW_LOOP;
                    end
                end

                RESULT: begin
                    result <= bell[n][0];
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule