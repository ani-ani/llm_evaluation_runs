module array_swap(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:15],
    input [3:0] len,
    output reg [7:0] result [0:15],
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CAPTURE = 2'd1;
    localparam [1:0] SWAP = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    reg [1:0] state;
    reg [7:0] captured_arr [0:15];
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd3;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            cycle_count <= 4'd0;
            for (i = 0; i < 16; i = i + 1) begin
                result[i] <= 8'd0;
                captured_arr[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        state <= CAPTURE;
                    end
                end

                CAPTURE: begin
                    cycle_count <= cycle_count + 4'd1;
                    for (i = 0; i < 16; i = i + 1) begin
                        captured_arr[i] <= arr[i];
                    end
                    state <= SWAP;
                end

                SWAP: begin
                    cycle_count <= cycle_count + 4'd1;
                    if (len >= 2) begin
                        result[0] <= captured_arr[len - 1];
                        result[len - 1] <= captured_arr[0];
                    end else begin
                        result[0] <= captured_arr[0];
                    end
                    for (i = 1; i < 16; i = i + 1) begin
                        if (i != len - 1) begin
                            result[i] <= captured_arr[i];
                        end
                    end
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule