module CountingMatrix(
    input clk,
    input rst_n,
    input start,
    input [19:0] n_high,
    input [19:0] n_low,
    input [19:0] t_high,
    input [19:0] t_low,
    output reg [31:0] result_high,
    output reg [31:0] result_low,
    output reg done
);

    // State definitions
    localparam [3:0] IDLE          = 4'd0;
    localparam [3:1] CHECK_T       = 4'd1;
    localparam [3:1] GET_N_PLUS_2  = 4'd2;
    localparam [3:1] FIND_K        = 4'd3;
    localparam [3:1] SETUP_LOOP    = 4'd4;
    localparam [3:1] CALC_COMB     = 4'd5;
    localparam [3:1] UPDATE_ACC    = 4'd6;
    localparam [3:1] FINISH_ADJUST = 4'd7;
    localparam [3:1] DONE_STATE    = 4'd8;

    reg [3:0] state, next_state;
    
    // Registers for inputs
    reg [39:0] n_reg;
    reg [39:0] t_reg;
    
    // Intermediate calculations
    reg [39:0] n_plus_2;
    reg [5:0] k;              // Bit position (0-39)
    reg [5:0] ones_count;     // Number of 1s seen so far (0-40)
    reg [5:0] bit_index;      // Current bit position (39 down to 0)
    reg [63:0] result_acc;    // Accumulated result
    
    // Binomial coefficient calculation state
    localparam [2:0] COMB_IDLE     = 3'd0;
    localparam [2:1] COMB_INIT     = 3'd1;
    localparam [2:1] COMB_LOOP     = 3'd2;
    localparam [2:1] COMB_DONE     = 3'd3;
    
    reg [2:0] comb_state;
    reg [5:0] comb_n;           // n in C(n, k)
    reg [5:0] comb_k;           // k in C(n, k)
    reg [5:0] comb_i;           // Loop variable
    reg [63:0] comb_result;     // Result of C(n, k)
    reg [63:0] comb_temp;       // Temporary for calculation
    
    // Flags
    reg is_power_of_two;
    reg t_is_one;
    reg bit_is_one;
    
    // 64-bit addition for result accumulation
    wire [63:0] next_result;
    assign next_result = result_acc + comb_result;
    
    // 40-bit addition for n+2
    wire [39:0] next_n_plus_2;
    assign next_n_plus_2 = n_reg + 40'd2;
    
    // Check if t is power of two (only need lower 20 bits of t_high for range 0-2^40)
    wire [39:0] t_val;
    assign t_val = {t_high, t_low};
    
    // Check power of two: t & (t-1) == 0
    wire [39:0] t_minus_1;
    assign t_minus_1 = t_val - 40'd1;
    wire is_pow2;
    assign is_pow2 = ((t_val & t_minus_1) == 40'd0) && (t_val != 40'd0);
    
    // Control signals
    reg start_comb;
    reg comb_valid;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_high <= 32'd0;
            result_low <= 32'd0;
            done <= 1'b0;
            n_reg <= 40'd0;
            t_reg <= 40'd0;
            n_plus_2 <= 40'd0;
            k <= 6'd0;
            ones_count <= 6'd0;
            bit_index <= 6'd0;
            result_acc <= 64'd0;
            comb_state <= COMB_IDLE;
            comb_n <= 6'd0;
            comb_k <= 6'd0;
            comb_i <= 6'd0;
            comb_result <= 64'd0;
            comb_temp <= 64'd0;
            is_power_of_two <= 1'b0;
            t_is_one <= 1'b0;
            bit_is_one <= 1'b0;
            start_comb <= 1'b0;
            comb_valid <= 1'b0;
        end else begin
            done <= 1'b0;
            start_comb <= 1'b0;
            comb_valid <= 1'b0;
            
            case (comb_state)
                COMB_IDLE: begin
                    if (start_comb) begin
                        comb_state <= COMB_INIT;
                    end
                end
                COMB_INIT: begin
                    // C(n, k) = n! / (k! * (n-k)!)
                    // We compute iteratively: result = 1, then multiply by (n-i)/(i+1)
                    // Start with result = 1
                    comb_result <= 64'd1;
                    comb_i <= 6'd0;
                    comb_state <= COMB_LOOP;
                end
                COMB_LOOP: begin
                    if (comb_i < comb_k) begin
                        // result = result * (n - i) / (i + 1)
                        // To avoid overflow and division, we can do sequential multiplication/division
                        // For small n (<= 40), intermediate values fit in 64 bits
                        // result = result * (comb_n - comb_i)
                        comb_temp <= comb_result * (comb_n - comb_i);
                        comb_state <= 3'd4; // Temporary state for division
                    end else begin
                        comb_state <= COMB_DONE;
                    end
                end
                3'd4: begin // Division state
                    // result = comb_temp / (comb_i + 1)
                    comb_result <= comb_temp / (comb_i + 6'd1);
                    comb_i <= comb_i + 6'd1;
                    comb_state <= COMB_LOOP;
                end
                COMB_DONE: begin
                    comb_valid <= 1'b1;
                    comb_state <= COMB_IDLE;
                end
                default: comb_state <= COMB_IDLE;
            endcase
            
            case (state)
                IDLE: begin
                    if (start) begin
                        n_reg <= {n_high, n_low};
                        t_reg <= {t_high, t_low};
                        state <= CHECK_T;
                    end
                end
                
                CHECK_T: begin
                    is_power_of_two <= is_pow2;
                    t_is_one <= (t_val == 40'd1);
                    if (!is_pow2) begin
                        // Not a power of two, answer is 0
                        result_acc <= 64'd0;
                        state <= DONE_STATE;
                    end else begin
                        state <= GET_N_PLUS_2;
                    end
                end
                
                GET_N_PLUS_2: begin
                    n_plus_2 <= next_n_plus_2;
                    state <= FIND_K;
                end
                
                FIND_K: begin
                    // Find k = log2(t)
                    // Since we know t is power of 2, find the bit position
                    if (t_val[39]) k <= 6'd39;
                    else if (t_val[38]) k <= 6'd38;
                    else if (t_val[37]) k <= 6'd37;
                    else if (t_val[36]) k <= 6'd36;
                    else if (t_val[35]) k <= 6'd35;
                    else if (t_val[34]) k <= 6'd34;
                    else if (t_val[33]) k <= 6'd33;
                    else if (t_val[32]) k <= 6'd32;
                    else if (t_val[31]) k <= 6'd31;
                    else if (t_val[30]) k <= 6'd30;
                    else if (t_val[29]) k <= 6'd29;
                    else if (t_val[28]) k <= 6'd28;
                    else if (t_val[27]) k <= 6'd27;
                    else if (t_val[26]) k <= 6'd26;
                    else if (t_val[25]) k <= 6'd25;
                    else if (t_val[24]) k <= 6'd24;
                    else if (t_val[23]) k <= 6'd23;
                    else if (t_val[22]) k <= 6'd22;
                    else if (t_val[21]) k <= 6'd21;
                    else if (t_val[20]) k <= 6'd20;
                    else if (t_val[19]) k <= 6'd19;
                    else if (t_val[18]) k <= 6'd18;
                    else if (t_val[17]) k <= 6'd17;
                    else if (t_val[16]) k <= 6'd16;
                    else if (t_val[15]) k <= 6'd15;
                    else if (t_val[14]) k <= 6'd14;
                    else if (t_val[13]) k <= 6'd13;
                    else if (t_val[12]) k <= 6'd12;
                    else if (t_val[11]) k <= 6'd11;
                    else if (t_val[10]) k <= 6'd10;
                    else if (t_val[9]) k <= 6'd9;
                    else if (t_val[8]) k <= 6'd8;
                    else if (t_val[7]) k <= 6'd7;
                    else if (t_val[6]) k <= 6'd6;
                    else if (t_val[5]) k <= 6'd5;
                    else if (t_val[4]) k <= 6'd4;
                    else if (t_val[3]) k <= 6'd3;
                    else if (t_val[2]) k <= 6'd2;
                    else if (t_val[1]) k <= 6'd1;
                    else k <= 6'd0;
                    
                    state <= SETUP_LOOP;
                end
                
                SETUP_LOOP: begin
                    bit_index <= 6'd39;
                    ones_count <= 6'd0;
                    result_acc <= 64'd0;
                    state <= CALC_COMB;
                end
                
                CALC_COMB: begin
                    if (bit_index < 6'd40) begin // Valid bit index (0-39)
                        // Check if current bit of n_plus_2 is 1
                        bit_is_one <= n_plus_2[bit_index];
                        
                        if (n_plus_2[bit_index]) begin
                            // We can set current bit to 0
                            // Need to count ways to have (k - ones_count) ones in remaining (bit_index) bits
                            // Remaining bits: bit_index positions (0 to bit_index-1)
                            
                            if (k >= ones_count && bit_index > 0) begin
                                comb_n <= bit_index; // Number of remaining positions
                                comb_k <= k - ones_count; // Number of 1s needed
                                start_comb <= 1'b1;
                            end
                            state <= 3'd10; // Wait for comb or skip
                        end else begin
                            // Bit is 0, we must set current bit to 0, just increment state
                            state <= UPDATE_ACC;
                        end
                    end else begin
                        state <= FINISH_ADJUST;
                    end
                end
                
                3'd10: begin // Wait state for comb calculation
                    if (comb_valid) begin
                        state <= UPDATE_ACC;
                    end else if (!start_comb && comb_state == COMB_IDLE) begin
                        // Combinatorics not needed (k < ones_count or bit_index == 0)
                        state <= UPDATE_ACC;
                    end
                end
                
                UPDATE_ACC: begin
                    // Add combinatorial count if applicable
                    if (bit_is_one && bit_index > 0 && k >= ones_count) begin
                        if (comb_valid) begin
                            result_acc <= next_result;
                        end
                    end
                    
                    // Increment ones_count if bit was 1
                    if (bit_is_one) begin
                        ones_count <= ones_count + 6'd1;
                    end
                    
                    // Decrement bit_index
                    bit_index <= bit_index - 6'd1;
                    state <= CALC_COMB;
                end
                
                FINISH_ADJUST: begin
                    // If t == 1 (k == 0), subtract 1
                    // This accounts for m=0 case (which is invalid as m >= 1)
                    if (t_is_one && result_acc > 0) begin
                        result_acc <= result_acc - 64'd1;
                    end
                    state <= DONE_STATE;
                end
                
                DONE_STATE: begin
                    result_high <= result_acc[63:32];
                    result_low <= result_acc[31:0];
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule