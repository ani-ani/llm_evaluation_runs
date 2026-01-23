module EvenNumberFilter (
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    input [2:0] len,
    output reg [7:0] result [0:7],
    output reg [2:0] output_len,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK = 3'd1;
    localparam [2:0] STORE = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    // Internal registers
    reg [2:0] state;
    reg [2:0] idx;          // Index through input array
    reg [2:0] result_idx;   // Index for output array
    reg [2:0] temp_len;     // Temporary output length counter
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            idx <= 3'd0;
            result_idx <= 3'd0;
            temp_len <= 3'd0;
            output_len <= 3'd0;
            done <= 1'b0;
            for (i = 0; i < 8; i = i + 1) begin
                result[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    idx <= 3'd0;
                    result_idx <= 3'd0;
                    temp_len <= 3'd0;
                    // Clear output array
                    for (i = 0; i < 8; i = i + 1) begin
                        result[i] <= 8'd0;
                    end
                    if (start) begin
                        state <= CHECK;
                    end
                end

                CHECK: begin
                    if (idx < len) begin
                        // Check if current element is even (bit 0 = 0)
                        if (arr[idx][0] == 1'b0) begin
                            state <= STORE;
                        end else begin
                            // Skip odd number
                            idx <= idx + 3'd1;
                            state <= CHECK;
                        end
                    end else begin
                        // Done processing all elements
                        output_len <= temp_len;
                        state <= DONE_STATE;
                    end
                end

                STORE: begin
                    // Store even number in output array
                    result[result_idx] <= arr[idx];
                    temp_len <= temp_len + 3'd1;
                    result_idx <= result_idx + 3'd1;
                    idx <= idx + 3'd1;
                    state <= CHECK;
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