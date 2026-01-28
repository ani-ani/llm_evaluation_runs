module ArrayThresholdCheck (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] threshold,
    input wire [7:0] arr [0:7],
    output reg result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] CHECK      = 3'd1;
    localparam [2:0] NEXT       = 3'd2;
    localparam [2:0] FINISH     = 3'd3;

    reg [2:0] state, next_state;
    reg [2:0] index;
    reg result_reg;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd15;

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            index <= 3'd0;
            result_reg <= 1'b0;
            cycle_count <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    index <= 3'd0;
                    result_reg <= 1'b0;  // Default to fail
                    cycle_count <= 4'd0;
                    if (start) begin
                        state <= CHECK;
                        // Initialize result_reg: if first element passes, set to 1
                        result_reg <= (arr[0] < threshold) ? 1'b1 : 1'b0;
                    end
                end

                CHECK: begin
                    cycle_count <= cycle_count + 4'd1;
                    // Compare current element
                    if (arr[index] >= threshold) begin
                        result_reg <= 1'b0;
                    end
                    state <= NEXT;
                end

                NEXT: begin
                    if (index < 3'd7) begin
                        index <= index + 3'd1;
                        state <= CHECK;
                    end else begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    result <= result_reg;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    result <= 1'b0;
                    done <= 1'b0;
                    index <= 3'd0;
                    result_reg <= 1'b0;
                    cycle_count <= 4'd0;
                end
            endcase
        end
    end

endmodule