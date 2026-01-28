module is_sorted(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    input [3:0] length,
    output reg result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] CHECK      = 3'd1;
    localparam [2:0] VALIDATE   = 3'd2;
    localparam [2:0] FINISH     = 3'd3;

    // Internal registers
    reg [2:0] state, next_state;
    reg [3:0] index;           // Current index to check
    reg [7:0] current_val;     // Value at index
    reg [7:0] next_val;        // Value at index+1
    reg [1:0] dup_count;       // Consecutive duplicate counter
    reg unsorted_flag;         // Flag for unsorted condition
    reg [7:0] cycle_count;     // Cycle counter for timeout

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = CHECK;
                else
                    next_state = IDLE;
            end
            CHECK: begin
                // Continue checking while index < length-1
                if (index < length - 1)
                    next_state = CHECK;
                else
                    next_state = VALIDATE;
            end
            VALIDATE: begin
                // One cycle to finalize result
                next_state = FINISH;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            index <= 4'd0;
            current_val <= 8'd0;
            next_val <= 8'd0;
            dup_count <= 2'd0;
            unsorted_flag <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    index <= 4'd0;
                    dup_count <= 2'd0;
                    unsorted_flag <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Initialize with first element
                        current_val <= arr[0];
                        // Check if length > 1
                        if (length > 1)
                            next_val <= arr[1];
                    end
                end

                CHECK: begin
                    // Check if next value >= current value (ascending)
                    if (next_val < current_val) begin
                        unsorted_flag <= 1'b1;
                    end

                    // Check duplicates
                    if (next_val == current_val) begin
                        dup_count <= dup_count + 2'd1;
                        if (dup_count >= 2'd2) begin
                            unsorted_flag <= 1'b1;
                        end
                    end else begin
                        dup_count <= 2'd0;  // Reset counter
                    end

                    // Move to next pair
                    if (index < length - 1) begin
                        index <= index + 4'd1;
                        current_val <= next_val;
                        if (index + 2 < length)
                            next_val <= arr[index + 2];
                    end
                end

                VALIDATE: begin
                    // Determine final result
                    if (unsorted_flag || cycle_count >= 8'd100)
                        result <= 1'b0;
                    else
                        result <= 1'b1;
                end

                FINISH: begin
                    done <= 1'b1;
                end

                default: begin
                    state <= IDLE;
                    result <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule