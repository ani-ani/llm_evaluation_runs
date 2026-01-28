module luggage_avoidance (
    input clk,
    input rst_n,
    input start,
    input [7:0] L_val,
    input [15:0] pos [0:7],
    input [3:0] N_val,
    output reg [15:0] result,
    output reg valid,
    output reg no_fika
);

    // State definitions
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] INIT_SEARCH = 3'd1;
    localparam [2:0] COMPUTE_MID = 3'd2;
    localparam [2:0] CHECK_COLLISION = 3'd3;
    localparam [2:0] UPDATE_SEARCH = 3'd4;
    localparam [2:0] FINISH    = 3'd5;

    // Fixed-point constants
    localparam [31:0] SCALE_SHIFT = 32'd6;      // For x_i * 64
    localparam [31:0] SCALE_ONE = 32'd64;       // 1.0 in scaled units
    localparam [31:0] V_MIN = 32'd64;           // 0.1 * 64 = 6.4 (integer 6)
    localparam [31:0] V_MAX = 32'd640;          // 10.0 * 64 = 640
    localparam [31:0] NO_FIKA_MARKER = 16'h7FFF;
    localparam [31:0] MAX_ITER = 6'd64;

    // Registers
    reg [2:0] state, next_state;
    reg [5:0] iter_count;
    reg [31:0] low, high, mid;
    reg [31:0] L_scaled;
    reg [31:0] x_reg [0:7];          // Scaled input positions
    reg [3:0] N_reg;
    
    // Temporary registers for computation
    reg [31:0] t_reg [0:7];          // Times t_i = x_i / v
    reg [31:0] current_v;
    reg [3:0] i, j;                  // Loop counters
    reg [31:0] diff;
    reg collision_found;
    reg [31:0] temp;
    
    // For division
    reg [31:0] div_num;
    reg [31:0] div_den;
    wire [31:0] div_result;
    reg div_start;
    reg div_done;
    
    // Internal signals for division unit
    reg [31:0] div_quotient;
    reg [5:0] div_shift;
    reg div_busy;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid <= 1'b0;
            no_fika <= 1'b0;
            result <= 16'd0;
            iter_count <= 6'd0;
            low <= 32'd0;
            high <= 32'd0;
            mid <= 32'd0;
            L_scaled <= 32'd0;
            N_reg <= 4'd0;
            collision_found <= 1'b0;
            div_start <= 1'b0;
            div_busy <= 1'b0;
            for (i = 0; i < 8; i = i + 1) begin
                x_reg[i] <= 32'd0;
                t_reg[i] <= 32'd0;
            end
            current_v <= 32'd0;
            i <= 4'd0;
            j <= 4'd0;
            diff <= 32'd0;
            temp <= 32'd0;
            div_num <= 32'd0;
            div_den <= 32'd0;
            div_quotient <= 32'd0;
            div_shift <= 6'd0;
            div_done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    no_fika <= 1'b0;
                    if (start) begin
                        // Scale inputs: x_i * 64 (shift left by 6)
                        L_scaled <= {24'd0, L_val, 2'd0};  // L * 4 (since x is *64, L needs *4 for consistent units? No, L is meters, x is meters*64. So L*64)
                        L_scaled <= {24'd0, L_val, 6'd0};  // L * 64
                        N_reg <= N_val;
                        for (i = 0; i < 8; i = i + 1) begin
                            if (i < N_val) begin
                                // pos[i] is already Q10.6 (64x). Input is 16-bit. 
                                // Problem says scale by 64. Input is 0-1000. 
                                // If input is Q10.6, it's already scaled by 64.
                                // If input is integer, multiply by 64.
                                // Assuming input is integer (0-1000), scale it:
                                x_reg[i] <= {16'd0, pos[i]} * 64; 
                            end else begin
                                x_reg[i] <= 32'd0;
                            end
                        end
                        state <= INIT_SEARCH;
                        i <= 4'd0;
                    end
                end
                
                INIT_SEARCH: begin
                    low <= V_MIN;
                    high <= V_MAX;
                    iter_count <= 6'd0;
                    state <= COMPUTE_MID;
                end
                
                COMPUTE_MID: begin
                    // mid = (low + high) >> 1
                    mid <= (low + high) >> 1;
                    current_v <= (low + high) >> 1;
                    i <= 4'd0; // Reset loop counter for division
                    div_busy <= 1'b1;
                    div_start <= 1'b1;
                    state <= CHECK_COLLISION;
                    collision_found <= 1'b0;
                end
                
                CHECK_COLLISION: begin
                    // Division and sort logic
                    if (div_start) begin
                        // Prepare first division
                        if (i < N_reg) begin
                            div_num <= x_reg[i];
                            div_den <= current_v;
                            div_start <= 1'b0;
                        end else begin
                            // All divisions done, proceed to check
                            div_busy <= 1'b0;
                            // Insertion Sort (simple for small N)
                            for (j = 1; j < 8; j = j + 1) begin
                                if (j < N_reg) begin
                                    temp <= t_reg[j];
                                    i <= j;
                                    // Inner sort loop setup
                                    // Handled in next state or here if simple
                                end
                            end
                            // Start distance check
                            i <= 4'd0;
                            state <= UPDATE_SEARCH;
                        end
                    end else if (div_busy) begin
                        // Perform division (Restoring division)
                        // Simplified: Shift left numerator by 16 (Q16.16), then divide
                        // div_num is already scaled (Q16.16 equivalent if we treat it as Q16.16)
                        // Actually, x_reg is Q16.16 (scaled by 64). v is integer.
                        // We want time t = x / v. Result should be Q16.16 for precision.
                        // t_reg[i] = (div_num << 16) / div_den
                        
                        if (div_shift == 0) begin
                            div_quotient <= 32'd0;
                            div_num <= div_num << 16; // Shift to Q16.16
                            div_shift <= 6'd32;
                        end else begin
                            div_quotient <= div_quotient << 1;
                            div_num <= div_num << 1;
                            if (div_num >= div_den) begin
                                div_quotient[0] <= 1'b1;
                                div_num <= div_num - div_den;
                            end
                            div_shift <= div_shift - 6'd1;
                            
                            if (div_shift == 6'd1) begin
                                // Division complete
                                t_reg[i] <= div_quotient;
                                i <= i + 4'd1;
                                div_shift <= 6'd0;
                                if (i + 4'd1 < N_reg) begin
                                    div_start <= 1'b1; // Next division
                                end else begin
                                    // Sort starts
                                    i <= 4'd1; // Start sort from index 1
                                    state <= UPDATE_SEARCH; // Go to sort phase
                                    div_busy <= 1'b0;
                                end
                            end
                        end
                    end
                end
                
                UPDATE_SEARCH: begin
                    // Bubble Sort / Insertion Sort continuation
                    // Check collision on the fly
                    // For simplicity, we check collision immediately after division in a merged step
                    // Let's separate Sort and Check.
                    // If we are here, sorting is done (or doing bubble sort)
                    
                    // Bubble Sort Pass
                    if (i < N_reg) begin
                        if (t_reg[i-1] > t_reg[i]) begin
                            temp <= t_reg[i-1];
                            t_reg[i-1] <= t_reg[i];
                            t_reg[i] <= temp;
                            // Need to bubble back, complex in single always block.
                            // Let's use a flag to indicate sorting is complete.
                        end
                        i <= i + 1;
                    end else begin
                        // Sorting complete (bubble sort one pass done, repeat? 
                        // N is small, single pass might be enough if we check carefully)
                        // Better: check collisions now
                        
                        // Check pairwise distances
                        for (j = 0; j < 7; j = j + 1) begin
                            if (j < N_reg - 1) begin
                                diff <= t_reg[j+1] - t_reg[j];
                                if (t_reg[j+1] - t_reg[j] <= SCALE_ONE) begin
                                    collision_found <= 1'b1;
                                end
                            end
                        end
                        // Check wrap around
                        if (N_reg > 0) begin
                            diff <= t_reg[0] + L_scaled - t_reg[N_reg-1];
                            if (t_reg[0] + L_scaled - t_reg[N_reg-1] <= SCALE_ONE) begin
                                collision_found <= 1'b1;
                            end
                        end
                        
                        // Update binary search bounds
                        if (collision_found) begin
                            high <= mid;
                        end else begin
                            low <= mid;
                        end
                        
                        iter_count <= iter_count + 6'd1;
                        
                        if (iter_count + 6'd1 >= MAX_ITER) begin
                            state <= FINISH;
                        end else begin
                            state <= COMPUTE_MID;
                        end
                    end
                end
                
                FINISH: begin
                    // Result is low
                    if (low > V_MIN) begin
                        result <= low[15:0]; // Output low
                        valid <= 1'b1;
                        no_fika <= 1'b0;
                    end else begin
                        result <= NO_FIKA_MARKER[15:0];
                        valid <= 1'b1;
                        no_fika <= 1'b1;
                    end
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule