module pos_counter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:7],
    input wire [3:0] len,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] PROC     = 2'd1;
    localparam [1:0] DONE     = 2'd2;

    // Internal signals
    reg [1:0] state;
    reg [2:0] idx;
    reg [3:0] cnt;
    reg [7:0] temp_val;
    reg [2:0] actual_len;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            idx <= 3'd0;
            cnt <= 4'd0;
            result <= 16'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 16'd0;
                    if (start) begin
                        state <= PROC;
                        idx <= 3'd0;
                        cnt <= 4'd0;
                        // Calculate actual length
                        if (len > 8) begin
                            actual_len <= 3'd7;
                        end else if (len == 0) begin
                            actual_len <= 3'd7;
                        end else begin
                            actual_len <= len - 4'd1;
                        end
                    end
                end

                PROC: begin
                    done <= 1'b0;
                    // Read current element
                    temp_val <= arr[idx];
                    // Check if non-negative (MSB = 0)
                    if (temp_val[7] == 1'b0) begin
                        cnt <= cnt + 4'd1;
                    end
                    // Move to next index
                    if (idx < actual_len) begin
                        idx <= idx + 3'd1;
                    end else begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    result <= cnt;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    result <= 16'd0;
                end
            endcase
        end
    end
endmodule