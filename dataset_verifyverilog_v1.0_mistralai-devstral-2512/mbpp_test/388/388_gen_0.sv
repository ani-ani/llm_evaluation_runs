module highest_power_of_2(
    input clk,
    input rst_n,
    input start,
    input [15:0] n,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] FINISH  = 3'd2;

    reg [2:0] state;
    reg [3:0] bit_pos;  // 4-bit counter for 16 iterations
    reg [15:0] temp;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            bit_pos <= 4'd0;
            temp <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    bit_pos <= 4'd0;
                    if (start) begin
                        state <= COMPUTE;
                        result <= 16'd0;
                    end
                end

                COMPUTE: begin
                    // Binary search: check current bit position
                    temp <= result | (1 << bit_pos);
                    if (temp <= n) begin
                        result <= temp;
                    end

                    // Move to next bit position
                    bit_pos <= bit_pos + 4'd1;

                    // Check if all bits processed
                    if (bit_pos == 4'd16) begin
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