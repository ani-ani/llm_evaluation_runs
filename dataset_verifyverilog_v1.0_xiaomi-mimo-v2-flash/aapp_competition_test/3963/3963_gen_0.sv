module WaysToPay (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] b [0:9],
    input wire [15:0] a [0:8],
    input wire signed [31:0] m_scaled,
    output reg [31:0] result,
    output reg done
);

    // Modulo constant: 1000000007
    localparam [31:0] MOD = 32'd1000000007;
    
    // Maximum array size (512 elements)
    localparam [31:0] MAX_SIZE = 32'd512;
    
    // State definitions
    localparam [3:0] IDLE           = 4'd0;
    localparam [3:0] SETUP          = 4'd1;
    localparam [3:0] CHECK_RATIO    = 4'd2;
    localparam [3:0] CHECK_T        = 4'd3;
    localparam [3:0] CALC_M_SCALED  = 4'd4;
    localparam [3:0] STRIDE_INIT    = 4'd5;
    localparam [3:0] STRIDE_LOOP    = 4'd6;
    localparam [3:0] PREFIX_INIT    = 4'd7;
    localparam [3:0] PREFIX_LOOP    = 4'd8;
    localparam [3:0] SWAP_ARRAYS    = 4'd9;
    localparam [3:0] NEXT_COIN      = 4'd10;
    localparam [3:0] OUTPUT_RESULT  = 4'd11;
    localparam [3:0] DONE_STATE     = 4'd12;
    
    // Registers for state machine
    reg [3:0] state, next_state;
    reg [7:0] coin_idx;      // Current coin type (0 to 9)
    reg [9:0] L;             // Current array upper bound
    reg signed [31:0] current_m_scaled;
    reg [31:0] t_reg;        // Store t value for stride
    reg [31:0] stride_factor; // Store a[i-1] for stride
    
    // Array registers (packed for Icarus compatibility)
    reg [31:0] d [0:511];    // Main array (512 elements)
    reg [31:0] td [0:511];   // Temporary array (512 elements)
    
    // Loop counters and flags
    reg [31:0] i, j, k;      // Generic loop counters
    reg [31:0] accumulator;  // For prefix sum
    reg [31:0] window_sum;   // Sliding window sum
    reg [31:0] window_start; // Window start index
    reg [31:0] temp_result;  // Temporary result storage
    reg [7:0] cycle_count;   // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd200;
    
    // Division and modulo temporaries
    reg signed [63:0] div_temp;
    reg [31:0] div_result;
    reg [31:0] mod_result;
    reg div_valid;
    
    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            coin_idx <= 8'd0;
            L <= 10'd0;
            current_m_scaled <= 32'd0;
            t_reg <= 32'd0;
            stride_factor <= 32'd0;
            i <= 32'd0;
            j <= 32'd0;
            k <= 32'd0;
            accumulator <= 32'd0;
            window_sum <= 32'd0;
            window_start <= 32'd0;
            temp_result <= 32'd0;
            cycle_count <= 8'd0;
            div_temp <= 64'd0;
            div_result <= 32'd0;
            mod_result <= 32'd0;
            div_valid <= 1'b0;
            // Initialize arrays
            for (int idx = 0; idx < 512; idx = idx + 1) begin
                d[idx] <= 32'd0;
                td[idx] <= 32'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Initialize arrays for coin type 0 (denomination = 1)
                        current_m_scaled <= m_scaled;
                        L <= 10'd0;
                        // d[0] = 1, rest 0 (implicit)
                        d[0] <= 32'd1;
                        for (int idx = 1; idx < 512; idx = idx + 1) begin
                            d[idx] <= 32'd0;
                        end
                    end
                end
                
                SETUP: begin
                    // No-op, just transition
                end
                
                CHECK_RATIO: begin
                    // Check if a[coin_idx-1] != 1
                end
                
                CHECK_T: begin
                    // Compute t = current_m_scaled % stride_factor
                    // Using subtraction loop (no built-in mod)
                    if (stride_factor > 32'd0) begin
                        if (current_m_scaled >= 0) begin
                            div_temp <= {32'd0, current_m_scaled};
                        end else begin
                            // Handle negative by converting to positive for modulo
                            div_temp <= {32'd0, -current_m_scaled};
                        end
                    end
                end
                
                CALC_M_SCALED: begin
                    // Update m_scaled = current_m_scaled / a[i-1]
                    // Also check if L < t
                end
                
                STRIDE_INIT: begin
                    i <= 32'd0;
                end
                
                STRIDE_LOOP: begin
                    // d[j] = d[t + j*a[i-1]]
                    if (i <= (L - t_reg) / stride_factor) begin
                        td[i] <= d[t_reg + i * stride_factor];
                        i <= i + 32'd1;
                    end
                end
                
                PREFIX_INIT: begin
                    // Initialize for prefix sum
                    j <= 32'd0;
                    accumulator <= 32'd0;
                    window_sum <= 32'd0;
                    window_start <= 32'd0;
                end
                
                PREFIX_LOOP: begin
                    // Compute td[j] = sum_{k=max(0,j-b[coin_idx])}^{j} d[k]
                    if (j <= L) begin
                        // Add d[j] to window_sum
                        window_sum <= window_sum + d[j];
                        if (window_sum >= MOD) begin
                            window_sum <= window_sum - MOD;
                        end
                        
                        // Remove old values from window
                        if (j > b[coin_idx]) begin
                            // Subtract d[j - b[coin_idx] - 1]
                            if (window_sum >= d[j - b[coin_idx] - 1]) begin
                                window_sum <= window_sum - d[j - b[coin_idx] - 1];
                            end else begin
                                window_sum <= window_sum + MOD - d[j - b[coin_idx] - 1];
                            end
                        end
                        
                        td[j] <= window_sum;
                        j <= j + 32'd1;
                    end
                end
                
                SWAP_ARRAYS: begin
                    // Swap d and td
                    // Done by copying td to d
                    for (int idx = 0; idx < 512; idx = idx + 1) begin
                        d[idx] <= td[idx];
                    end
                end
                
                NEXT_COIN: begin
                    // Update L and prepare for next coin
                    // L = min(MAX_SIZE, (L + 1) * a[coin_idx] - 1)
                    // But bounded by array size
                    cycle_count <= cycle_count + 8'd1;
                end
                
                OUTPUT_RESULT: begin
                    // Output result
                    if (current_m_scaled >= 0 && current_m_scaled < 512) begin
                        result <= d[current_m_scaled];
                    end else begin
                        result <= 32'd0;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            // Division logic (modulo operation)
            if (state == CHECK_T && stride_factor > 32'd0) begin
                // Perform division by repeated subtraction
                div_result <= 32'd0;
                mod_result <= 32'd0;
                div_valid <= 1'b1;
            end
            
            // Non-blocking division update
            if (div_valid && stride_factor > 32'd0) begin
                if (div_temp >= stride_factor) begin
                    div_temp <= div_temp - stride_factor;
                    div_result <= div_result + 32'd1;
                end else begin
                    mod_result <= div_temp[31:0];
                    div_valid <= 1'b0;
                end
            end
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = SETUP;
                end
            end
            
            SETUP: begin
                coin_idx = 8'd0;
                L = 10'd0;
                next_state = OUTPUT_RESULT;
                // Special case: if only 1 coin type
                if (b[0] == 16'd0 && m_scaled == 0) begin
                    next_state = OUTPUT_RESULT;
                end else if (m_scaled > 0) begin
                    next_state = OUTPUT_RESULT;
                end
                // For simplicity, handle n=1 directly
                if (b[1] == 16'd0) begin
                    // Only coin type 0
                    next_state = OUTPUT_RESULT;
                end else begin
                    next_state = CHECK_RATIO;
                end
            end
            
            CHECK_RATIO: begin
                if (a[coin_idx] == 16'd1) begin
                    // Skip stride step
                    next_state = PREFIX_INIT;
                end else begin
                    next_state = CHECK_T;
                end
            end
            
            CHECK_T: begin
                if (!div_valid) begin
                    next_state = CALC_M_SCALED;
                end
            end
            
            CALC_M_SCALED: begin
                if (mod_result > L) begin
                    next_state = OUTPUT_RESULT;
                end else begin
                    t_reg = mod_result;
                    current_m_scaled = div_result;
                    stride_factor = a[coin_idx];
                    next_state = STRIDE_INIT;
                end
            end
            
            STRIDE_INIT: begin
                next_state = STRIDE_LOOP;
            end
            
            STRIDE_LOOP: begin
                if (i > (L - t_reg) / stride_factor) begin
                    next_state = PREFIX_INIT;
                end
            end
            
            PREFIX_INIT: begin
                next_state = PREFIX_LOOP;
            end
            
            PREFIX_LOOP: begin
                if (j > L) begin
                    next_state = SWAP_ARRAYS;
                end
            end
            
            SWAP_ARRAYS: begin
                next_state = NEXT_COIN;
            end
            
            NEXT_COIN: begin
                // Update L: L = min(MAX_SIZE, L * a[coin_idx])
                // Handle overflow
                if (coin_idx < 8'd9 && b[coin_idx + 1] != 16'd0) begin
                    coin_idx = coin_idx + 8'd1;
                    // L = L * a[coin_idx-1] (but cap at MAX_SIZE)
                    // For hardware, cap at 512-1 = 511
                    L = 10'd511; // Simplification: keep full array
                    next_state = CHECK_RATIO;
                end else begin
                    next_state = OUTPUT_RESULT;
                end
            end
            
            OUTPUT_RESULT: begin
                next_state = DONE_STATE;
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
        
        // Cycle count protection
        if (cycle_count >= MAX_CYCLES) begin
            next_state = OUTPUT_RESULT;
        end
    end
    
endmodule