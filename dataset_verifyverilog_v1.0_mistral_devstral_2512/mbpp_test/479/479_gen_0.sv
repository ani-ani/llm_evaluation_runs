module first_digit_finder (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] num_in,
    output reg [7:0] first_digit,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [7:0] current_num;
    reg [3:0] iteration_count;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_num <= 8'd0;
            iteration_count <= 4'd0;
            first_digit <= 8'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                        current_num <= num_in;
                        iteration_count <= 4'd0;
                    end
                end

                COMPUTE: begin
                    if (current_num >= 8'd10 && iteration_count < 4'd8) begin
                        // Divide by 10 (current_num / 10)
                        current_num <= current_num / 8'd10;
                        iteration_count <= iteration_count + 4'd1;
                    end else begin
                        state <= COMPLETE;
                    end
                end

                COMPLETE: begin
                    first_digit <= current_num;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule