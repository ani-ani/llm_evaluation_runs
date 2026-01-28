module median_length_calculator(
    input clk,
    input rst_n,
    input [7:0] base1,
    input [7:0] base2,
    input [7:0] height,
    input start,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] OUTPUT = 2'd2;

    reg [1:0] state;
    reg [8:0] sum;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            sum <= 9'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    sum <= base1 + base2;
                    state <= OUTPUT;
                end

                OUTPUT: begin
                    result <= sum >> 1;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule