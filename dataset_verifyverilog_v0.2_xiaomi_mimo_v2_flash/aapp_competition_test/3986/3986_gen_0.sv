module string_generator(
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    input [4:0] k,
    output reg [1023:0] result,
    output reg [7:0] length_out,
    output reg valid,
    output reg error
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam CHECK = 3'b001;
    localparam GEN_LOOP = 3'b010;
    localparam FINISH = 3'b011;
    localparam ERROR_STATE = 3'b100;

    reg [2:0] state, next_state;
    
    // Internal registers for generation loop
    reg [7:0] current_idx; // Current character position being generated (0 to n-1)
    reg [7:0] prefix_len;  // Length of alternating prefix
    reg [7:0] fill_char;   // Current fill character value (ASCII)
    reg [7:0] char_count;  // Count of distinct characters used
    reg [7:0] n_reg;       // Registered n
    reg [4:0] k_reg;       // Registered k
    
    // Combinational logic for next state and outputs
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = CHECK;
                else next_state = IDLE;
            end
            
            CHECK: begin
                // Check invalid conditions
                if (k_reg > 26 || (k_reg == 1 && n_reg > 1) || (n_reg < k_reg && k_reg > 1)) begin
                    next_state = ERROR_STATE;
                end else begin
                    next_state = GEN_LOOP;
                end
            end
            
            GEN_LOOP: begin
                // Loop until all n characters are generated
                if (current_idx >= n_reg && n_reg != 0)
                    next_state = FINISH;
                else
                    next_state = GEN_LOOP;
                    
                // Edge case: n=0, immediate finish
                if (n_reg == 0 && current_idx == 0)
                    next_state = FINISH;
            end
            
            FINISH: begin
                // Hold state until reset or new start
                next_state = FINISH;
                if (!rst_n) next_state = IDLE;
                if (start) next_state = CHECK; // Allow restart
            end
            
            ERROR_STATE: begin
                // Hold error state
                next_state = ERROR_STATE;
                if (!rst_n) next_state = IDLE;
                if (start) next_state = CHECK;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1024'b0;
            length_out <= 8'b0;
            valid <= 1'b0;
            error <= 1'b0;
            current_idx <= 8'b0;
            prefix_len <= 8'b0;
            fill_char <= 8'b0;
            char_count <= 8'b0;
            n_reg <= 8'b0;
            k_reg <= 5'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        n_reg <= n;
                        k_reg <= k;
                        current_idx <= 8'b0;
                        valid <= 1'b0;
                        error <= 1'b0;
                        result <= 1024'b0;
                        length_out <= 8'b0;
                    end
                end
                
                CHECK: begin
                    // Logic handled in next_state decision, but we prepare registers for GEN_LOOP
                    if (!(k_reg > 26 || (k_reg == 1 && n_reg > 1) || (n_reg < k_reg && k_reg > 1))) begin
                        // Valid inputs, prepare for generation
                        if (n_reg == 1 && k_reg == 1) begin
                            // Special case handled in IDLE->CHECK transition logic or simply treated as valid
                            // We will handle it in GEN_LOOP
                        end else if (n_reg > 1) begin
                            // Calculate prefix_len = n - (k - 2)
                            // If k=1, this case is invalid (handled above), so k>=2 here for valid cases with n>1
                            if (k_reg >= 2)
                                prefix_len <= n_reg - (k_reg - 2);
                            else
                                prefix_len <= n_reg; // Should not happen if valid
                        end
                        fill_char <= 8'b0; // Reset counters
                        current_idx <= 8'b0;
                    end
                end
                
                GEN_LOOP: begin
                    if (current_idx < n_reg) begin
                        // Generate character logic
                        if (n_reg == 1 && k_reg == 1) begin
                            // Single character 'a'
                            result[7:0] <= 8'h61; // 'a'
                            current_idx <= 8'd1;
                        end else begin
                            // Logic for general generation
                            if (current_idx < prefix_len) begin
                                // Alternating 'a' and 'b'
                                if (current_idx[0] == 1'b0) begin
                                    // Even index: 'a'
                                    result[current_idx*8 +: 8] <= 8'h61;
                                end else begin
                                    // Odd index: 'b'
                                    result[current_idx*8 +: 8] <= 8'h62;
                                end
                            end else begin
                                // Fill remaining with 'c' + (current_idx - prefix_len)
                                // Start with 'c' (8'h63)
                                result[current_idx*8 +: 8] <= 8'h63 + (current_idx - prefix_len);
                            end
                            current_idx <= current_idx + 1;
                        end
                    end
                end
                
                FINISH: begin
                    // Complete result should be valid now
                    // Update length_out only if n > 0
                    if (n_reg != 0)
                        length_out <= n_reg;
                    else
                        length_out <= 8'd0;
                    valid <= 1'b1;
                end
                
                ERROR_STATE: begin
                    error <= 1'b1;
                    length_out <= 8'b0;
                    result <= 1024'b0;
                end
            endcase
        end
    end

endmodule
