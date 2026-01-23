module executive_reward (
    input clk,
    input rst_n,
    input start,
    input [2:0] num_briefcases,
    input [23:0] bananas [0:7],
    output reg [7:0] max_executives,
    output reg done
);

    // States
    localparam IDLE = 2'b00;
    localparam COMPUTE = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state;
    reg [2:0] i; // Index for briefcases
    reg [2:0] k; // Index for groups
    reg [7:0] exec_count;
    reg [23:0] prev_sum;
    reg [23:0] curr_sum;
    reg [23:0] group_sums [0:7]; // Store sums of groups (max 8 groups)
    reg processing_done;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            max_executives <= 8'd0;
            done <= 1'b0;
            exec_count <= 8'd0;
            prev_sum <= 24'd0;
            curr_sum <= 24'd0;
            i <= 3'd0;
            k <= 3'd0;
            processing_done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                        i <= 3'd0;
                        k <= 3'd0;
                        exec_count <= 8'd0;
                        prev_sum <= 24'd0;
                        curr_sum <= 24'd0;
                        processing_done <= 1'b0;
                    end
                end

                COMPUTE: begin
                    // Iterate through briefcases (i from 0 to num_briefcases-1)
                    if (i < num_briefcases) begin
                        // Accumulate current group sum
                        curr_sum <= curr_sum + bananas[i];

                        // Check if current accumulated sum >= previous group sum
                        // We must compare the new sum (curr_sum + bananas[i]) with prev_sum
                        // To avoid combinational loop on curr_sum, we use a temporary check
                        // Here we rely on the fact that we update curr_sum in the clock edge.
                        // The check for the decision needs to be on the *accumulated* value.
                        // However, standard logic: add, then check. 
                        // If we check (curr_sum + bananas[i]) >= prev_sum, we need logic.
                        // Since we are sequential, let's look at the result of the addition.
                        // Note: curr_sum update happens at posedge. The value used in the if condition
                        // is the *old* curr_sum. So we must perform the check on the *next* state or combinational.
                        // To keep it purely sequential and simple for the greedy algorithm:
                        // We will perform the check logic inside the state machine.

                        // Actually, let's use a combinational next_sum logic to decide immediately or a multi-cycle approach.
                        // Given the latency requirement (approx 64 cycles), multi-cycle is fine.

                        // Let's redesign the COMPUTE state logic slightly to be clear:
                        // We will add bananas[i] to curr_sum, then in the SAME cycle check if we can close the group.
                        // But curr_sum updates at the end of the cycle. 
                        // So we check: (curr_sum + bananas[i]) >= prev_sum ?

                        if ((curr_sum + bananas[i]) >= prev_sum) begin
                            // Close current group
                            // The sum of this group is (curr_sum + bananas[i])
                            // Store it
                            group_sums[k] <= curr_sum + bananas[i];
                            prev_sum <= curr_sum + bananas[i];
                            curr_sum <= 24'd0; // Reset for next group
                            exec_count <= exec_count + 1;
                            k <= k + 1;
                        end else begin
                            // Continue accumulating in current group (implicit, curr_sum updates below)
                            // We need to make sure curr_sum gets the new value.
                            // Since we are inside the if (i < num_briefcases), we handle the addition.
                            // The line "curr_sum <= curr_sum + bananas[i]" is already there.
                        end

                        i <= i + 1;
                    end else begin
                        // Finished iterating all briefcases
                        // If curr_sum is not zero, we have a last group (unless we reset it on exact match)
                        // In the greedy algorithm, if we have leftover bananas, they form the last executive.
                        if (curr_sum > 0 || (num_briefcases > 0 && exec_count == 0)) begin
                             // If exec_count is 0, it means we never hit the condition (e.g. only 1 briefcase or very small numbers)
                             // Actually, if we never hit the condition, curr_sum holds the sum of all briefcases.
                             // The logic above: if condition met, we close group and reset curr_sum.
                             // If condition never met, curr_sum holds all values.
                             // In that case, we have 1 group.
                             if (exec_count == 0) begin
                                 exec_count <= 8'd1;
                             end else begin
                                 exec_count <= exec_count + 1;
                             end
                        end
                        state <= DONE;
                    end
                end

                DONE: begin
                    max_executives <= exec_count;
                    done <= 1'b1;
                    if (!start) begin
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule