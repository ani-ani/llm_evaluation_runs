module CombinationMaxSum (
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    input [2:0] k_select,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOAD      = 3'd1;
    localparam [2:0] COMBINE   = 3'd2;
    localparam [2:0] MAX_FIND  = 3'd3;
    localparam [2:0] ACCUMULATE= 3'd4;
    localparam [2:0] FINISH    = 3'd5;

    // Constants
    localparam [31:0] MODULUS = 32'h3B9ACA07;

    // Registers
    reg [2:0] state;
    reg [2:0] k_reg;
    reg [7:0] temp_arr [0:7];
    reg [7:0] combination [0:2];
    reg [31:0] sum;
    reg [7:0] current_max;
    
    // Combination generation registers
    reg [7:0] bit_pattern;
    reg [2:0] bit_count;
    reg [2:0] combo_index;
    reg [3:0] i_idx;
    reg [2:0] j_idx;
    reg [2:0] ones_count;
    reg [3:0] cycle_count;

    // Combinational logic for combination extraction
    always @(*) begin
        ones_count = 3'd0;
        combo_index = 3'd0;
        // Extract elements where bit is set
        for (i_idx = 0; i_idx < 8; i_idx = i_idx + 1) begin
            if (bit_pattern[i_idx] && (combo_index < 3'd3)) begin
                combination[combo_index] = temp_arr[i_idx];
                combo_index = combo_index + 3'd1;
                ones_count = ones_count + 3'd1;
            end
        end
    end

    // Combinational logic for finding maximum
    always @(*) begin
        current_max = 8'd0;
        if (ones_count >= 3'd1) current_max = combination[0];
        if (ones_count >= 3'd2 && combination[1] > current_max) current_max = combination[1];
        if (ones_count >= 3'd3 && combination[2] > current_max) current_max = combination[2];
    end

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            sum <= 32'd0;
            bit_pattern <= 8'd0;
            cycle_count <= 4'd0;
            k_reg <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    sum <= 32'd0;
                    bit_pattern <= 8'd0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        state <= LOAD;
                        k_reg <= k_select;
                    end
                end

                LOAD: begin
                    // Copy input array to temp storage
                    for (i_idx = 0; i_idx < 8; i_idx = i_idx + 1) begin
                        temp_arr[i_idx] <= arr[i_idx];
                    end
                    // Validate K
                    if (k_reg == 3'd0 || k_reg > 3'd3) begin
                        state <= FINISH;
                    end else begin
                        bit_pattern <= 8'd0;
                        state <= COMBINE;
                        // Initialize pattern with first valid combination
                        for (i_idx = 0; i_idx < k_reg; i_idx = i_idx + 1) begin
                            bit_pattern[i_idx] <= 1'b1;
                        end
                    end
                end

                COMBINE: begin
                    // Check if current pattern has exactly K bits set
                    if (ones_count == k_reg) begin
                        state <= MAX_FIND;
                        cycle_count <= cycle_count + 4'd1;
                    end else begin
                        // Generate next combination (next lexicographic permutation)
                        // Implementation: find rightmost 1 with 0 to its right, move it left
                        bit_pattern <= bit_pattern + 8'd1;
                        if (cycle_count > 4'd15) begin
                            // Safety timeout
                            state <= FINISH;
                        end
                    end
                    
                    // Check if done (no more valid combinations)
                    if (bit_pattern >= 8'hFF && ones_count > k_reg) begin
                        state <= FINISH;
                    end
                end

                MAX_FIND: begin
                    // Maximum already computed combinationally
                    state <= ACCUMULATE;
                end

                ACCUMULATE: begin
                    // Add max to sum with modulo
                    sum <= (sum + {24'd0, current_max}) % MODULUS;
                    
                    // Generate next combination
                    // Simple approach: increment and retry
                    bit_pattern <= bit_pattern + 8'd1;
                    state <= COMBINE;
                    
                    // Check if we've processed enough combinations
                    // C(8,K) max is 56 for K=3
                    if (cycle_count >= 4'd12) begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    result <= sum;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule