module CountGoodPlans(
    input clk,
    input rst_n,
    input start,
    input [8:0] a_i [0:99],
    input [6:0] n,
    input [8:0] m,
    input [8:0] b,
    input [29:0] mod,
    output reg [29:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CALCULATING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // DP buffer (2 rows for rolling)
    reg [29:0] dp_prev [0:500];
    reg [29:0] dp_curr [0:500];

    // State and control registers
    reg [1:0] state;
    reg [8:0] line_count;
    reg [8:0] bug_count;
    reg [6:0] programmer_count;
    reg [8:0] max_lines;
    reg [8:0] max_bugs;

    // Initialize DP buffer
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 30'd0;
            done <= 1'b0;
            line_count <= 9'd0;
            bug_count <= 9'd0;
            programmer_count <= 7'd0;
            max_lines <= 9'd0;
            max_bugs <= 9'd0;

            // Clear DP buffers
            for (i = 0; i < 501; i = i + 1) begin
                dp_prev[i] <= 30'd0;
                dp_curr[i] <= 30'd0;
            end
            dp_prev[0] <= 30'd1;  // Base case: 0 lines, 0 bugs
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= CALCULATING;
                        programmer_count <= 7'd0;
                        max_lines <= m;
                        max_bugs <= b;

                        // Initialize DP buffer for new calculation
                        for (i = 0; i < 501; i = i + 1) begin
                            dp_prev[i] <= 30'd0;
                            dp_curr[i] <= 30'd0;
                        end
                        dp_prev[0] <= 30'd1;
                    end
                end

                CALCULATING: begin
                    if (programmer_count < n) begin
                        // Process current programmer
                        if (line_count == 0) begin
                            // Start new programmer iteration
                            if (bug_count == 0) begin
                                // Copy dp_prev to dp_curr for new iteration
                                for (i = 0; i < 501; i = i + 1) begin
                                    dp_curr[i] <= dp_prev[i];
                                end
                                line_count <= 9'd1;
                                bug_count <= 9'd0;
                            end else begin
                                bug_count <= bug_count + 9'd1;
                                if (bug_count > max_bugs) begin
                                    bug_count <= 9'd0;
                                    line_count <= line_count + 9'd1;
                                end
                            end
                        end else if (line_count <= max_lines) begin
                            // Update DP for current line and bug count
                            if (bug_count <= max_bugs) begin
                                reg [29:0] sum;
                                if (bug_count >= a_i[programmer_count]) begin
                                    sum = dp_curr[bug_count] + dp_prev[bug_count - a_i[programmer_count]];
                                end else begin
                                    sum = dp_curr[bug_count];
                                end
                                dp_curr[bug_count] <= sum % mod;

                                // Move to next bug count
                                bug_count <= bug_count + 9'd1;
                                if (bug_count > max_bugs) begin
                                    bug_count <= 9'd0;
                                    line_count <= line_count + 9'd1;
                                end
                            end else begin
                                bug_count <= 9'd0;
                                line_count <= line_count + 9'd1;
                            end

                            // Check if done with current programmer
                            if (line_count > max_lines) begin
                                // Copy dp_curr back to dp_prev for next programmer
                                for (i = 0; i < 501; i = i + 1) begin
                                    dp_prev[i] <= dp_curr[i];
                                end
                                programmer_count <= programmer_count + 7'd1;
                                line_count <= 9'd0;
                                bug_count <= 9'd0;
                            end
                        end
                    end else begin
                        // All programmers processed, move to DONE state
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    // Output result and return to IDLE
                    result <= dp_prev[m] % mod;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule