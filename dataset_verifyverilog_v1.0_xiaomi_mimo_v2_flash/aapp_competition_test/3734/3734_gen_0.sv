module day_checker (
    input clk,
    input rst_n,
    input start,
    input [2:0] day1,
    input [2:0] day2,
    output reg result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [2:0] diff;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            diff <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                        // Calculate (day2 - day1 + 7) % 7
                        if (day2 >= day1) begin
                            diff <= day2 - day1;
                        end else begin
                            diff <= (day2 + 7) - day1;
                        end
                    end
                end

                COMPUTE: begin
                    // Check if difference is 0, 2, or 3
                    if ((diff == 3'd0) || (diff == 3'd2) || (diff == 3'd3)) begin
                        result <= 1'b1;
                    end else begin
                        result <= 1'b0;
                    end
                    state <= COMPLETE;
                end

                COMPLETE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule