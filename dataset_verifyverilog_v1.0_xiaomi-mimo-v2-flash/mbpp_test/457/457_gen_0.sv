module MinLengthSublistFinder (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] sublist_packed [0:3],
    input wire [3:0] valid_len [0:3],
    output reg [63:0] result_packed,
    output reg [3:0] result_len,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] INIT       = 3'd1;
    localparam [2:0] COMPARE    = 3'd2;
    localparam [2:0] UPDATE     = 3'd3;
    localparam [2:0] OUTPUT     = 3'd4;
    localparam [2:0] FINISH     = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [1:0] idx;  // Index for current sublist (0-3)
    reg [3:0] min_len_reg;
    reg [1:0] min_idx_reg;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd15;  // 4 sublists, 4 cycles each + overhead

    // FSM Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_packed <= 64'd0;
            result_len <= 4'd0;
            done <= 1'b0;
            idx <= 2'd0;
            min_len_reg <= 4'd0;
            min_idx_reg <= 2'd0;
            cycle_count <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    // Initialize with first sublist
                    min_len_reg <= valid_len[0];
                    min_idx_reg <= 2'd0;
                    idx <= 2'd1;  // Start comparing from sublist 1
                    state <= COMPARE;
                end

                COMPARE: begin
                    if (idx < 2'd4) begin
                        // Compare current sublist with current minimum
                        if (valid_len[idx] < min_len_reg) begin
                            state <= UPDATE;
                        end else begin
                            // Move to next sublist
                            idx <= idx + 2'd1;
                            state <= COMPARE;
                        end
                        cycle_count <= cycle_count + 4'd1;
                    end else begin
                        // All sublists compared
                        state <= OUTPUT;
                    end
                end

                UPDATE: begin
                    min_len_reg <= valid_len[idx];
                    min_idx_reg <= idx;
                    idx <= idx + 2'd1;  // Move to next sublist
                    state <= COMPARE;
                end

                OUTPUT: begin
                    // Load result with minimum sublist
                    result_packed <= sublist_packed[min_idx_reg];
                    result_len <= min_len_reg;
                    state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule