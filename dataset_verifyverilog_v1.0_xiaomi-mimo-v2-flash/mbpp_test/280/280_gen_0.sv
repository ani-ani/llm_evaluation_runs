module sequential_search (
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:15],
    input [7:0] item,
    input [3:0] len,
    output reg found,
    output reg [3:0] index,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CHECKING = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;

    // Internal registers
    reg [1:0] state, next_state;
    reg [3:0] idx_counter, next_idx_counter;
    reg found_reg, next_found_reg;
    reg [3:0] index_reg, next_index_reg;
    reg done_reg, next_done_reg;
    reg [4:0] cycle_count, next_cycle_count; // 5 bits for 0-16 count

    // State transition and output logic
    always @(*) begin
        next_state = state;
        next_idx_counter = idx_counter;
        next_found_reg = found_reg;
        next_index_reg = index_reg;
        next_done_reg = 1'b0;
        next_cycle_count = cycle_count;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CHECKING;
                    next_idx_counter = 4'd0;
                    next_found_reg = 1'b0;
                    next_index_reg = 4'd0;
                    next_cycle_count = 5'd0;
                end
            end

            CHECKING: begin
                next_cycle_count = cycle_count + 5'd1;
                
                // Compare current element with item
                if (arr[idx_counter] == item) begin
                    next_found_reg = 1'b1;
                    next_index_reg = idx_counter;
                    next_state = COMPLETE;
                end else begin
                    // Check if reached end of array or max cycles
                    if (idx_counter >= len - 4'd1 || cycle_count >= 5'd15) begin
                        next_found_reg = 1'b0;
                        next_state = COMPLETE;
                    end else begin
                        next_idx_counter = idx_counter + 4'd1;
                    end
                end
            end

            COMPLETE: begin
                next_done_reg = 1'b1;
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            idx_counter <= 4'd0;
            found_reg <= 1'b0;
            index_reg <= 4'd0;
            done_reg <= 1'b0;
            cycle_count <= 5'd0;
            found <= 1'b0;
            index <= 4'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            idx_counter <= next_idx_counter;
            found_reg <= next_found_reg;
            index_reg <= next_index_reg;
            done_reg <= next_done_reg;
            cycle_count <= next_cycle_count;
            found <= next_found_reg;
            index <= next_index_reg;
            done <= next_done_reg;
        end
    end

endmodule