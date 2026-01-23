module bell_numbers(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    output reg [63:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT = 3'd1;
    localparam [2:0] LOOP_I = 3'd2;
    localparam [2:0] LOOP_J = 3'd3;
    localparam [2:0] UPDATE = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    // Internal registers
    reg [2:0] state;
    reg [3:0] i, j;
    reg [63:0] bell [0:8][0:8];
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1000;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 64'd0;
            i <= 4'd0;
            j <= 4'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= INIT;
                        i <= 4'd0;
                        j <= 4'd0;
                    end
                end

                INIT: begin
                    bell[0][0] <= 64'd1;
                    i <= 4'd1;
                    j <= 4'd0;
                    state <= LOOP_I;
                end

                LOOP_I: begin
                    if (i <= n) begin
                        bell[i][0] <= bell[i-1][i-1];
                        j <= 4'd1;
                        state <= LOOP_J;
                    end else begin
                        state <= FINISH;
                    end
                end

                LOOP_J: begin
                    if (j <= i) begin
                        state <= UPDATE;
                    end else begin
                        i <= i + 4'd1;
                        j <= 4'd0;
                        state <= LOOP_I;
                    end
                end

                UPDATE: begin
                    bell[i][j] <= bell[i-1][j-1] + bell[i][j-1];
                    j <= j + 4'd1;
                    state <= LOOP_J;
                end

                FINISH: begin
                    result <= bell[n][0];
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule