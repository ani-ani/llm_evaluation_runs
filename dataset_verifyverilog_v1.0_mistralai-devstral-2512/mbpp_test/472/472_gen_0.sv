module ConsecutiveChecker(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:7],
    output reg consecutive,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] FIND_MIN_MAX = 3'd1;
    localparam [2:0] CHECK_DIFF = 3'd2;
    localparam [2:0] CHECK_DUPLICATES = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Min/Max registers
    reg [7:0] min_val;
    reg [7:0] max_val;
    reg [8:0] diff_val;

    // Duplicate detection
    reg [7:0] i_reg, j_reg;
    reg duplicate_found;
    reg [7:0] current_i, current_j;

    // FSM state transitions
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            consecutive <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            min_val <= 8'd0;
            max_val <= 8'd0;
            diff_val <= 9'd0;
            i_reg <= 8'd0;
            j_reg <= 8'd0;
            duplicate_found <= 1'b0;
            current_i <= 8'd0;
            current_j <= 8'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    consecutive <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= FIND_MIN_MAX;
                        // Initialize min/max with first element
                        min_val <= arr[0];
                        max_val <= arr[0];
                    end else begin
                        next_state <= IDLE;
                    end
                end

                FIND_MIN_MAX: begin
                    // Compare elements 1-7 with current min/max
                    if (arr[1] < min_val) min_val <= arr[1];
                    if (arr[1] > max_val) max_val <= arr[1];
                    if (arr[2] < min_val) min_val <= arr[2];
                    if (arr[2] > max_val) max_val <= arr[2];
                    if (arr[3] < min_val) min_val <= arr[3];
                    if (arr[3] > max_val) max_val <= arr[3];
                    if (arr[4] < min_val) min_val <= arr[4];
                    if (arr[4] > max_val) max_val <= arr[4];
                    if (arr[5] < min_val) min_val <= arr[5];
                    if (arr[5] > max_val) max_val <= arr[5];
                    if (arr[6] < min_val) min_val <= arr[6];
                    if (arr[6] > max_val) max_val <= arr[6];
                    if (arr[7] < min_val) min_val <= arr[7];
                    if (arr[7] > max_val) max_val <= arr[7];

                    next_state <= CHECK_DIFF;
                end

                CHECK_DIFF: begin
                    // Calculate difference (9-bit to handle max 255-0=255)
                    diff_val <= {1'b0, max_val} - {1'b0, min_val};

                    // Check if difference is exactly 7
                    if (diff_val == 9'd7) begin
                        next_state <= CHECK_DUPLICATES;
                        i_reg <= 8'd0;
                        j_reg <= 8'd0;
                        duplicate_found <= 1'b0;
                    end else begin
                        next_state <= DONE_STATE;
                        consecutive <= 1'b0;
                    end
                end

                CHECK_DUPLICATES: begin
                    // Iterate through all pairs
                    current_i <= i_reg;
                    current_j <= j_reg;

                    if (current_i < 8'd7) begin
                        if (current_j < 8'd7) begin
                            if (current_j != current_i && arr[current_j] == arr[current_i]) begin
                                duplicate_found <= 1'b1;
                            end
                            j_reg <= j_reg + 8'd1;
                        end else begin
                            i_reg <= i_reg + 8'd1;
                            j_reg <= 8'd0;
                        end
                        next_state <= CHECK_DUPLICATES;
                    end else begin
                        // Check if all numbers are within [min, max] range
                        reg [7:0] k;
                        reg all_in_range;
                        all_in_range = 1'b1;
                        for (k = 0; k < 8; k = k + 1) begin
                            if (arr[k] < min_val || arr[k] > max_val) begin
                                all_in_range = 1'b0;
                            end
                        end

                        if (!duplicate_found && all_in_range) begin
                            consecutive <= 1'b1;
                        end else begin
                            consecutive <= 1'b0;
                        end
                        next_state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                    consecutive <= 1'b0;
                end
            endcase

            // Timeout protection
            if (cycle_count >= MAX_CYCLES) begin
                next_state <= IDLE;
                done <= 1'b1;
                consecutive <= 1'b0;
            end
        end
    end

endmodule