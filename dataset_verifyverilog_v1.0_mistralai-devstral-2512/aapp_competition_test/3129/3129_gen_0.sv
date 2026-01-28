module min_ops_to_sort(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire s_0,
    input wire s_1,
    input wire s_2,
    input wire s_3,
    input wire s_4,
    input wire s_5,
    input wire s_6,
    input wire s_7,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] SORTING  = 2'd1;
    localparam [1:0] CHECKING = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    // Registers
    reg [1:0] state, next_state;
    reg [7:0] seq_reg;
    reg [7:0] op_count;
    reg [2:0] window_idx;
    reg [7:0] cycle_count;
    reg swap_occurred;
    localparam [7:0] MAX_CYCLES = 8'd64;

    // Initialize registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            seq_reg <= 8'd0;
            op_count <= 8'd0;
            window_idx <= 3'd0;
            cycle_count <= 8'd0;
            swap_occurred <= 1'b0;
            result <= 8'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Load input sequence
                        seq_reg[0] <= s_0;
                        seq_reg[1] <= s_1;
                        seq_reg[2] <= s_2;
                        seq_reg[3] <= s_3;
                        seq_reg[4] <= s_4;
                        seq_reg[5] <= s_5;
                        seq_reg[6] <= s_6;
                        seq_reg[7] <= s_7;
                        op_count <= 8'd0;
                        window_idx <= 3'd0;
                        cycle_count <= 8'd0;
                        swap_occurred <= 1'b0;
                        next_state <= CHECKING;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                CHECKING: begin
                    // Check if sequence is sorted
                    reg is_sorted;
                    is_sorted = 1'b1;
                    for (integer i = 0; i < 7; i = i + 1) begin
                        if (seq_reg[i] > seq_reg[i+1]) begin
                            is_sorted = 1'b0;
                        end
                    end

                    if (is_sorted || cycle_count >= MAX_CYCLES) begin
                        result <= op_count;
                        next_state <= DONE_STATE;
                    end else begin
                        window_idx <= 3'd0;
                        swap_occurred <= 1'b0;
                        next_state <= SORTING;
                    end
                end

                SORTING: begin
                    // Sort current window
                    reg [2:0] window_bits;
                    window_bits[0] = seq_reg[window_idx];
                    window_bits[1] = seq_reg[window_idx + 1];
                    window_bits[2] = seq_reg[window_idx + 2];

                    // Count number of 1s in window
                    reg [1:0] count_ones;
                    count_ones = window_bits[0] + window_bits[1] + window_bits[2];

                    // Sort the window
                    case (count_ones)
                        2'd0: begin
                            // Already sorted (0,0,0)
                        end
                        2'd1: begin
                            // Move the single 1 to the right
                            seq_reg[window_idx]     <= 1'b0;
                            seq_reg[window_idx + 1] <= 1'b0;
                            seq_reg[window_idx + 2] <= 1'b1;
                            swap_occurred <= 1'b1;
                        end
                        2'd2: begin
                            // Move the single 0 to the left
                            seq_reg[window_idx]     <= 1'b0;
                            seq_reg[window_idx + 1] <= 1'b1;
                            seq_reg[window_idx + 2] <= 1'b1;
                            swap_occurred <= 1'b1;
                        end
                        2'd3: begin
                            // Already sorted (1,1,1)
                        end
                    endcase

                    // Move to next window
                    if (window_idx == 3'd5) begin
                        if (swap_occurred) begin
                            op_count <= op_count + 8'd1;
                        end
                        cycle_count <= cycle_count + 8'd1;
                        next_state <= CHECKING;
                    end else begin
                        window_idx <= window_idx + 3'd1;
                        next_state <= SORTING;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                end
            endcase
        end
    end

endmodule