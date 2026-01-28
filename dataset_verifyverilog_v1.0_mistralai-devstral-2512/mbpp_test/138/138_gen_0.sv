module sum_of_powers_of_two(
    input [7:0] n,
    input clk,
    input rst_n,
    input start,
    output reg result,
    output reg done,
    output reg valid
);

    // State declarations
    localparam [0:0] IDLE = 1'b0;
    localparam [0:0] WORK = 1'b1;
    reg [0:0] state;
    reg [7:0] n_reg;

    // Combinatorial logic for result
    wire comb_result = ~n[0];

    // Sequential logic for registered operation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            n_reg <= 8'd0;
            result <= 1'b0;
            done <= 1'b0;
            valid <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    if (start) begin
                        n_reg <= n;
                        state <= WORK;
                    end
                end
                WORK: begin
                    result <= ~n_reg[0];
                    done <= 1'b1;
                    valid <= 1'b1;
                    state <= IDLE;
                end
                default: state <= IDLE;
            endcase
        end
    end

    // Combinatorial mode: direct pass-through
    always @(*) begin
        if (state == IDLE && !start) begin
            result = comb_result;
            valid = 1'b1;
        end
    end

endmodule