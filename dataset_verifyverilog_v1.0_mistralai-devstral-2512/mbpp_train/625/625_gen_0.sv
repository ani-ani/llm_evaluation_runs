module array_swap(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    input [3:0] len,
    output reg [7:0] result [0:7],
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SWAP = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            cycle_count <= 8'd0;
            for (i = 0; i < 8; i = i + 1) begin
                result[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= SWAP;
                    end
                end

                SWAP: begin
                    cycle_count <= cycle_count + 8'd1;

                    for (i = 0; i < 8; i = i + 1) begin
                        if (i == 0) begin
                            result[i] <= arr[len - 1];
                        end else if (i == len - 1) begin
                            result[i] <= arr[0];
                        end else begin
                            result[i] <= arr[i];
                        end
                    end

                    if (cycle_count >= MAX_CYCLES) begin
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