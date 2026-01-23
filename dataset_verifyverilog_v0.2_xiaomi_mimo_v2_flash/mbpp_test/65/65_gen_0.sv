module recursive_list_sum (
    input clk,
    input rst_n,
    input start,
    input [15:0] data [0:3][0:3],
    output reg [31:0] total_sum,
    output reg done
);

    // State Encoding
    localparam IDLE = 2'b00;
    localparam SUMMING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state, next_state;
    reg [3:0] count, next_count; // Counts 0 to 15
    reg [31:0] next_total_sum;
    reg next_done;

    // Helper logic to map count to 2D index
    // count[3:2] -> row index (0-3)
    // count[1:0] -> col index (0-3)
    wire [15:0] current_element = data[count[3:2]][count[1:0]];

    // State Register and Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            total_sum <= 32'b0;
            done <= 1'b0;
            count <= 4'b0;
        end else begin
            state <= next_state;
            total_sum <= next_total_sum;
            done <= next_done;
            count <= next_count;
        end
    end

    // Next State Logic
    always @(*) begin
        // Default assignments
        next_state = state;
        next_total_sum = total_sum;
        next_done = done;
        next_count = count;

        case (state)
            IDLE: begin
                next_total_sum = 32'b0;
                next_done = 1'b0;
                next_count = 4'b0;
                if (start) begin
                    next_state = SUMMING;
                end
            end

            SUMMING: begin
                next_total_sum = total_sum + {16'b0, current_element};
                next_count = count + 1'b1;
                
                // 16 cycles (0 to 15) processing
                if (count == 4'hF) begin // If count was 15, next is 0 (or just finished logic)
                    // To match exactly 16 cycles of accumulation, we check if we just added the 16th element.
                    // Since count increments after add, checking if we just processed index 15 means count==15.
                    // We should transition to DONE on the cycle after processing the 15th index.
                    // Wait, let's re-read: "Iterate through... 4x4 matrix... 16 for data processing".
                    // If count is 4 bits, let's check if we have processed all elements.
                    // When count is 15 (0xF), we are processing the last element.
                    // Next cycle, count becomes 0 (or unused in SUMMING).
                    // We should transition to DONE when the last addition is complete.
                    // Let's increment count first, then check.
                    // Actually, standard practice: increment counter, then check limit.
                    // But here, we need to add valid data.
                    // Let's stick to the instruction "16 for data processing".
                    // If we count 0 to 15, that is 16 values.
                    // When count == 4'b1111 (15), we add element 15.
                    // In the same cycle, we can check if this is the last one.
                    // However, sequential logic updates next cycle.
                    // Let's use the condition: if (count == 4'b1111) transition to DONE.
                    // This implies we just finished the 16th element (index 15).
                    // Wait, typically we want to transition to DONE *after* the 16th element is accumulated.
                    // If count is 0 initially, we add element 0.
                    // If count is 15, we add element 15.
                    // On the next clock, we should be in DONE.
                    // So, inside SUMMING state:
                    // If count is already 15 (meaning we just processed 15), move to DONE.
                    // But here `next_count` is being assigned `count + 1`. 
                    // So `count` is the OLD value.
                    // If OLD value is 15, we process index 15. After this cycle, we should be done.
                    // Let's check `next_count` maybe? 
                    // Let's just check `next_count`. If `next_count` hits 16 (which is 4'b10000), we are done.
                    // Since count is 4 bits, 4'b10000 wraps to 0. 
                    // Let's use a flag.
                    if (count == 4'd15) begin
                        next_state = DONE;
                    end
                end
            end

            DONE: begin
                next_done = 1'b1;
                next_state = IDLE; // Self-resetting or wait for external reset. 
                                   // "Wait for start signal" implies returning to IDLE logic.
                                   // Or staying in DONE until reset. 
                                   // The description says "1 for idle, 16 for data processing". 
                                   // It doesn't explicitly say "hold DONE", but "Output total_sum and assert done".
                                   // Usually, done goes high for one cycle.
                next_done = 1'b1;
                next_state = IDLE; // Single cycle pulse for done, then back to idle.
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule
