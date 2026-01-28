module dial_game(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] A,
    input wire [3:0] B,
    output reg [6:0] result,
    output reg done
);

    // Parameters
    localparam N = 8;
    localparam WIDTH = 4;

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CALC_SUM = 2'd1;
    localparam [1:0] UPDATE = 2'd2;
    localparam [1:0] FINISH = 2'd3;

    // Registers
    reg [1:0] state;
    reg [3:0] idx;
    reg [6:0] sum;
    reg [3:0] a_reg, b_reg;
    reg [WIDTH-1:0] dials [0:N-1];

    // Initialize dials to 0
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 7'd0;
            sum <= 7'd0;
            idx <= 4'd0;
            a_reg <= 4'd0;
            b_reg <= 4'd0;
            for (i = 0; i < N; i = i + 1) begin
                dials[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        a_reg <= A - 4'd1;
                        b_reg <= B - 4'd1;
                        sum <= 7'd0;
                        idx <= a_reg;
                        state <= CALC_SUM;
                    end
                end

                CALC_SUM: begin
                    if (idx <= b_reg) begin
                        sum <= sum + dials[idx];
                        idx <= idx + 4'd1;
                    end else begin
                        result <= sum;
                        idx <= a_reg;
                        state <= UPDATE;
                    end
                end

                UPDATE: begin
                    if (idx <= b_reg) begin
                        if (dials[idx] == 4'd9) begin
                            dials[idx] <= 4'd0;
                        end else begin
                            dials[idx] <= dials[idx] + 4'd1;
                        end
                        idx <= idx + 4'd1;
                    end else begin
                        state <= FINISH;
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