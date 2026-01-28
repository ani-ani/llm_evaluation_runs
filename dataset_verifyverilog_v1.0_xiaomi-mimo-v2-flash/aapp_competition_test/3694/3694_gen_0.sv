module stones_game_winner (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] len,
    input wire [31:0] arr [0:15],
    output reg [1:0] result,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE         = 4'd0;
    localparam [3:0] SAMPLE       = 4'd1;
    localparam [3:0] CHECK_DUPE   = 4'd2;
    localparam [3:0] CHECK_DUP_VAL = 4'd3;
    localparam [3:0] CHECK_PREV   = 4'd4;
    localparam [3:0] CALC_TOTAL   = 4'd5;
    localparam [3:0] FINISH       = 4'd6;

    // Internal registers
    reg [3:0] state, next_state;
    reg [31:0] sorted_arr [0:15];
    reg [3:0] n_reg;
    reg [3:0] i;
    reg [3:0] dup_count;
    reg [31:0] dup_value;
    reg [63:0] total_sum;
    reg [63:0] total_calc;
    reg [31:0] n_minus_1;
    reg [31:0] n_div_2;
    reg has_prev;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd100;

    // Combinational sorting logic
    reg [31:0] temp;
    integer j, k;
    reg [3:0] swap_i;
    
    // Helper for sorting
    always @(*) begin
        // Copy and bubble sort in combinational block
        for (i = 0; i < 16; i = i + 1) begin
            sorted_arr[i] = arr[i];
        end
        
        // Bubble sort
        for (j = 0; j < 15; j = j + 1) begin
            for (k = 0; k < 15 - j; k = k + 1) begin
                if (sorted_arr[k] > sorted_arr[k+1]) begin
                    temp = sorted_arr[k];
                    sorted_arr[k] = sorted_arr[k+1];
                    sorted_arr[k+1] = temp;
                end
            end
        end
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 2'd0;
            done <= 1'b0;
            n_reg <= 4'd0;
            dup_count <= 4'd0;
            dup_value <= 32'd0;
            total_sum <= 64'd0;
            total_calc <= 64'd0;
            n_minus_1 <= 32'd0;
            n_div_2 <= 32'd0;
            has_prev <= 1'b0;
            cycle_count <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        n_reg <= len;
                        state <= SAMPLE;
                    end
                end

                SAMPLE: begin
                    // Start checking duplicates from index 1
                    i <= 4'd1;
                    dup_count <= 4'd0;
                    dup_value <= 32'd0;
                    state <= CHECK_DUPE;
                end

                CHECK_DUPE: begin
                    cycle_count <= cycle_count + 4'd1;
                    if (i < n_reg) begin
                        if (sorted_arr[i] == sorted_arr[i-1]) begin
                            dup_count <= dup_count + 4'd1;
                            dup_value <= sorted_arr[i];
                        end
                        i <= i + 4'd1;
                    end else begin
                        // Check multiple duplicates
                        if (dup_count > 4'd1) begin
                            result <= 2'd0; // CSL wins
                            state <= FINISH;
                        end else if (dup_count == 4'd1) begin
                            i <= 4'd0;
                            has_prev <= 1'b0;
                            state <= CHECK_PREV;
                        end else begin
                            state <= CALC_TOTAL;
                        end
                    end
                end

                CHECK_PREV: begin
                    cycle_count <= cycle_count + 4'd1;
                    if (i < n_reg) begin
                        // Check if (dup_value - 1) exists
                        if (i > 0 && sorted_arr[i] == (dup_value - 1)) begin
                            has_prev <= 1'b1;
                        end
                        i <= i + 4'd1;
                    end else begin
                        // Check duplicate value conditions
                        if (dup_value == 32'd0 || has_prev) begin
                            result <= 2'd0; // CSL wins
                            state <= FINISH;
                        end else begin
                            state <= CALC_TOTAL;
                        end
                    end
                end

                CALC_TOTAL: begin
                    cycle_count <= cycle_count + 4'd1;
                    // Calculate total = sum(a) - n*(n-1)/2
                    // First compute sum
                    total_sum <= 64'd0;
                    i <= 4'd0;
                    state <= FINISH; // Will compute sum in combinational
                end

                FINISH: begin
                    done <= 1'b1;
                    // Compute final result based on parity
                    if (total_calc[0] == 1'b0) begin
                        result <= 2'd0; // CSL wins (even)
                    end else begin
                        result <= 2'd1; // Tokitsukaze wins (odd)
                    end
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Combinational calculation for total
    always @(*) begin
        // Compute sum of all elements
        total_sum = 64'd0;
        for (i = 0; i < 16; i = i + 1) begin
            if (i < n_reg) begin
                total_sum = total_sum + {32'd0, sorted_arr[i]};
            end
        end
        
        // Compute n*(n-1)/2
        n_minus_1 = n_reg - 32'd1;
        n_div_2 = (n_reg * n_minus_1) >> 1;
        
        // Final calculation
        if (total_sum >= {32'd0, n_div_2}) begin
            total_calc = total_sum - {32'd0, n_div_2};
        end else begin
            total_calc = 64'd0;
        end
    end

endmodule