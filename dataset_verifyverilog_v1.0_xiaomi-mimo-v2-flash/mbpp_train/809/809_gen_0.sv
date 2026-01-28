module check_array_greater(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr1 [0:7],
    input wire [7:0] arr2 [0:7],
    input wire [3:0] len,
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] CHECKING  = 3'd1;
    localparam [2:0] FAILED    = 3'd2;
    localparam [2:0] SUCCESS   = 3'd3;
    localparam [2:0] FINISHED  = 3'd4;

    reg [2:0] state;
    reg [3:0] index;
    reg fail_flag;
    reg [2:0] cycle_count;  // Max 8 cycles

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            index <= 4'd0;
            fail_flag <= 1'b0;
            cycle_count <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 3'd0;
                    index <= 4'd0;
                    fail_flag <= 1'b0;
                    result <= 1'b0;
                    if (start && len > 4'd0) begin
                        state <= CHECKING;
                    end else if (start && len == 4'd0) begin
                        // Empty array: should pass (no elements to fail)
                        state <= SUCCESS;
                    end
                end

                CHECKING: begin
                    cycle_count <= cycle_count + 3'd1;
                    
                    // Compare current element
                    if (arr1[index] <= arr2[index]) begin
                        fail_flag <= 1'b1;
                        state <= FAILED;
                    end else begin
                        // Check if all elements processed
                        if (index >= len - 4'd1) begin
                            state <= SUCCESS;
                        end else begin
                            index <= index + 4'd1;
                            // Safety: prevent infinite loops
                            if (cycle_count >= 3'd7) begin
                                state <= FAILED;
                            end
                        end
                    end
                end

                FAILED: begin
                    result <= 1'b0;
                    state <= FINISHED;
                end

                SUCCESS: begin
                    result <= 1'b1;
                    state <= FINISHED;
                end

                FINISHED: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    result <= 1'b0;
                    done <= 1'b0;
                    index <= 4'd0;
                    fail_flag <= 1'b0;
                    cycle_count <= 3'd0;
                end
            endcase
        end
    end

endmodule