module incr_list(
    input clk,
    input rst_n,
    input start,
    input [3:0] len,
    input [7:0] arr [0:7],
    output reg [7:0] result [0:7],
    output reg done,
    output reg valid
);

    // State declarations
    localparam [1:0] IDLE       = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state;
    reg [3:0] index;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            done <= 1'b0;
            valid <= 1'b0;
            cycle_count <= 8'd0;
            // Initialize result array
            result[0] <= 8'd0;
            result[1] <= 8'd0;
            result[2] <= 8'd0;
            result[3] <= 8'd0;
            result[4] <= 8'd0;
            result[5] <= 8'd0;
            result[6] <= 8'd0;
            result[7] <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= PROCESSING;
                        index <= 4'd0;
                    end
                end

                PROCESSING: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Process current element
                    if (index < len) begin
                        result[index] <= arr[index] + 8'd1;
                        index <= index + 4'd1;
                    end
                    // Check if done processing
                    if (index >= len || cycle_count >= MAX_CYCLES) begin
                        state <= DONE_STATE;
                        valid <= 1'b1;
                    end
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