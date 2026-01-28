module string_multiset_checker(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] s0_len,
    input wire [3:0] s1_len,
    input wire [7:0] s0_char_0,
    input wire [7:0] s0_char_1,
    input wire [7:0] s0_char_2,
    input wire [7:0] s0_char_3,
    input wire [7:0] s0_char_4,
    input wire [7:0] s0_char_5,
    input wire [7:0] s0_char_6,
    input wire [7:0] s0_char_7,
    input wire [7:0] s0_char_8,
    input wire [7:0] s0_char_9,
    input wire [7:0] s0_char_10,
    input wire [7:0] s0_char_11,
    input wire [7:0] s0_char_12,
    input wire [7:0] s0_char_13,
    input wire [7:0] s0_char_14,
    input wire [7:0] s0_char_15,
    input wire [7:0] s1_char_0,
    input wire [7:0] s1_char_1,
    input wire [7:0] s1_char_2,
    input wire [7:0] s1_char_3,
    input wire [7:0] s1_char_4,
    input wire [7:0] s1_char_5,
    input wire [7:0] s1_char_6,
    input wire [7:0] s1_char_7,
    input wire [7:0] s1_char_8,
    input wire [7:0] s1_char_9,
    input wire [7:0] s1_char_10,
    input wire [7:0] s1_char_11,
    input wire [7:0] s1_char_12,
    input wire [7:0] s1_char_13,
    input wire [7:0] s1_char_14,
    input wire [7:0] s1_char_15,
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE         = 3'd0;
    localparam [2:0] CHECK_LENGTH = 3'd1;
    localparam [2:0] COUNT_S0     = 3'd2;
    localparam [2:0] COUNT_S1     = 3'd3;
    localparam [2:0] COMPARE      = 3'd4;
    localparam [2:0] DONE_STATE   = 3'd5;
    
    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [8:0] s0_hist [0:255];  // 9-bit counters for s0 histogram
    reg [8:0] s1_hist [0:255];  // 9-bit counters for s1 histogram
    reg [7:0] char_addr;        // Current character address for iteration
    reg [3:0] char_idx;         // Current character index for counting
    reg mismatch_flag;          // Flag for comparison mismatch
    reg [7:0] s0_len_reg;       // Registered length for comparison
    reg [7:0] s1_len_reg;       // Registered length for comparison
    reg [7:0] cycle_count;      // Cycle counter to prevent infinite loops
    
    // Helper signals for character selection
    reg [7:0] s0_current_char;
    reg [7:0] s1_current_char;
    
    // Constants
    localparam [7:0] MAX_CYCLES = 8'd200;
    localparam [7:0] MAX_LEN = 8'd15;
    
    // Sequential logic: State transitions and outputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            char_addr <= 8'd0;
            char_idx <= 4'd0;
            mismatch_flag <= 1'b0;
            s0_len_reg <= 8'd0;
            s1_len_reg <= 8'd0;
            cycle_count <= 8'd0;
            // Initialize histograms to zero
            for (integer i = 0; i < 256; i = i + 1) begin
                s0_hist[i] <= 9'd0;
                s1_hist[i] <= 9'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    mismatch_flag <= 1'b0;
                    cycle_count <= 8'd0;
                    char_addr <= 8'd0;
                    char_idx <= 4'd0;
                    if (start) begin
                        s0_len_reg <= {4'd0, s0_len};
                        s1_len_reg <= {4'd0, s1_len};
                        state <= CHECK_LENGTH;
                    end
                end
                
                CHECK_LENGTH: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (s0_len != s1_len) begin
                        result <= 1'b0;
                        state <= DONE_STATE;
                    end else begin
                        state <= COUNT_S0;
                        char_idx <= 4'd0;
                    end
                end
                
                COUNT_S0: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (char_idx < s0_len) begin
                        // Get current character
                        case (char_idx)
                            4'd0: s0_current_char <= s0_char_0;
                            4'd1: s0_current_char <= s0_char_1;
                            4'd2: s0_current_char <= s0_char_2;
                            4'd3: s0_current_char <= s0_char_3;
                            4'd4: s0_current_char <= s0_char_4;
                            4'd5: s0_current_char <= s0_char_5;
                            4'd6: s0_current_char <= s0_char_6;
                            4'd7: s0_current_char <= s0_char_7;
                            4'd8: s0_current_char <= s0_char_8;
                            4'd9: s0_current_char <= s0_char_9;
                            4'd10: s0_current_char <= s0_char_10;
                            4'd11: s0_current_char <= s0_char_11;
                            4'd12: s0_current_char <= s0_char_12;
                            4'd13: s0_current_char <= s0_char_13;
                            4'd14: s0_current_char <= s0_char_14;
                            4'd15: s0_current_char <= s0_char_15;
                            default: s0_current_char <= 8'd0;
                        endcase
                        // Increment histogram count
                        if (s0_hist[s0_current_char] < 9'd512) begin
                            s0_hist[s0_current_char] <= s0_hist[s0_current_char] + 9'd1;
                        end
                        char_idx <= char_idx + 4'd1;
                    end else begin
                        state <= COUNT_S1;
                        char_idx <= 4'd0;
                    end
                end
                
                COUNT_S1: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (char_idx < s1_len) begin
                        // Get current character
                        case (char_idx)
                            4'd0: s1_current_char <= s1_char_0;
                            4'd1: s1_current_char <= s1_char_1;
                            4'd2: s1_current_char <= s1_char_2;
                            4'd3: s1_current_char <= s1_char_3;
                            4'd4: s1_current_char <= s1_char_4;
                            4'd5: s1_current_char <= s1_char_5;
                            4'd6: s1_current_char <= s1_char_6;
                            4'd7: s1_current_char <= s1_char_7;
                            4'd8: s1_current_char <= s1_char_8;
                            4'd9: s1_current_char <= s1_char_9;
                            4'd10: s1_current_char <= s1_char_10;
                            4'd11: s1_current_char <= s1_char_11;
                            4'd12: s1_current_char <= s1_char_12;
                            4'd13: s1_current_char <= s1_char_13;
                            4'd14: s1_current_char <= s1_char_14;
                            4'd15: s1_current_char <= s1_char_15;
                            default: s1_current_char <= 8'd0;
                        endcase
                        // Increment histogram count
                        if (s1_hist[s1_current_char] < 9'd512) begin
                            s1_hist[s1_current_char] <= s1_hist[s1_current_char] + 9'd1;
                        end
                        char_idx <= char_idx + 4'd1;
                    end else begin
                        state <= COMPARE;
                        char_addr <= 8'd0;
                    end
                end
                
                COMPARE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (char_addr < 8'd255) begin
                        // Compare current histogram entry
                        if (s0_hist[char_addr] != s1_hist[char_addr]) begin
                            mismatch_flag <= 1'b1;
                        end
                        char_addr <= char_addr + 8'd1;
                    end else begin
                        // Last comparison
                        if (s0_hist[8'd255] != s1_hist[8'd255] || mismatch_flag) begin
                            result <= 1'b0;
                        end else begin
                            result <= 1'b1;
                        end
                        state <= DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
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