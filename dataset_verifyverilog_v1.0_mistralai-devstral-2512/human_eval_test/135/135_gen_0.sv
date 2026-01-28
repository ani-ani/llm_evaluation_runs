module can_arrange(
    input clk,
    input rst_n,
    input start,
    input signed [7:0] arr [0:15],
    input [3:0] len,
    output reg signed [3:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    reg [1:0] state;
    reg [3:0] i;
    reg found;
    reg [7:0] arr_reg [0:15];
    reg [3:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Sample array on start
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            i <= 4'd0;
            found <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Sample array
                        integer j;
                        for (j = 0; j < 16; j = j + 1) begin
                            arr_reg[j] <= arr[j];
                        end
                        state <= PROCESS;
                        i <= 4'd1;
                        found <= 1'b0;
                        result <= 4'd0;
                    end
                end

                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (i < len) begin
                        if (arr_reg[i] < arr_reg[i-1]) begin
                            result <= i;
                            found <= 1'b1;
                        end
                        i <= i + 4'd1;
                    end else begin
                        if (!found) begin
                            result <= 4'd15; // -1 in 4-bit signed
                        end
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