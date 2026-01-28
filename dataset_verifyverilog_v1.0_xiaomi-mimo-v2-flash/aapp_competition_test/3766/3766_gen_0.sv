module HanabiHints (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] card_type [0:24],
    input wire [0:24] valid_types,
    input wire [6:0] num_cards,
    output reg [3:0] result,
    output reg done,
    output reg valid
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INIT_LOOP = 3'd1;
    localparam [2:0] CHECK_HINT = 3'd2;
    localparam [2:0] CHECK_DUPLICATE = 3'd3;
    localparam [2:0] UPDATE_MIN = 3'd4;
    localparam [2:0] FINISH = 3'd5;
    
    // Registers and wires
    reg [2:0] state;
    reg [2:0] next_state;
    
    reg [9:0] hint_mask;  // 10 bits for 5 colors + 5 values
    reg [9:0] best_mask;
    reg [3:0] min_hints;
    reg [3:0] current_hints;
    
    reg [2:0] type_idx;  // 0-24
    reg [2:0] dup_idx;   // 0-24
    reg [7:0] sig [0:24];  // Signatures for each valid type
    reg [7:0] current_sig;
    reg [7:0] check_sig;
    reg found_duplicate;
    
    // Helper to count bits in 10-bit value
    function automatic [3:0] count_ones(input [9:0] val);
        reg [3:0] cnt;
        integer i;
    begin
        cnt = 4'd0;
        for (i = 0; i < 10; i = i + 1) begin
            if (val[i]) cnt = cnt + 4'd1;
        end
        count_ones = cnt;
    end
    endfunction
    
    // Combinational helper to compute signature
    reg [7:0] sig_temp;
    integer i;
    
    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            valid <= 1'b0;
            hint_mask <= 10'd0;
            best_mask <= 10'd0;
            min_hints <= 4'd10;
            current_hints <= 4'd0;
            type_idx <= 3'd0;
            dup_idx <= 3'd0;
            found_duplicate <= 1'b0;
            current_sig <= 8'd0;
            check_sig <= 8'd0;
            sig_temp <= 8'd0;
            // Initialize sig array
            for (i = 0; i < 25; i = i + 1) begin
                sig[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    if (start) begin
                        state <= INIT_LOOP;
                        hint_mask <= 10'd0;
                        best_mask <= 10'd0;
                        min_hints <= 4'd10;
                        type_idx <= 3'd0;
                        dup_idx <= 3'd0;
                        found_duplicate <= 1'b0;
                    end
                end
                
                INIT_LOOP: begin
                    // Initialize loop for next hint_mask
                    found_duplicate <= 1'b0;
                    type_idx <= 3'd0;
                    dup_idx <= 3'd0;
                    state <= CHECK_HINT;
                end
                
                CHECK_HINT: begin
                    // Compute signature for current type_idx
                    if (valid_types[type_idx]) begin
                        sig_temp <= card_type[type_idx] & {2'd0, hint_mask};
                    end else begin
                        sig_temp <= 8'd0;
                    end
                    state <= CHECK_DUPLICATE;
                    dup_idx <= type_idx;
                end
                
                CHECK_DUPLICATE: begin
                    // Store computed signature
                    if (valid_types[type_idx]) begin
                        sig[type_idx] <= sig_temp;
                    end
                    
                    // Check for duplicates
                    if (type_idx < 3'd24) begin
                        type_idx <= type_idx + 3'd1;
                        state <= CHECK_HINT;
                    end else begin
                        // All signatures computed, now check for duplicates
                        type_idx <= 3'd0;
                        dup_idx <= 3'd0;
                        state <= UPDATE_MIN;
                    end
                end
                
                UPDATE_MIN: begin
                    // Check if current hint_mask is valid (no duplicates)
                    // We'll check duplicates in combinational logic below
                    // For now, assume found_duplicate is set by comb block
                    if (!found_duplicate) begin
                        current_hints <= count_ones(hint_mask);
                        if (count_ones(hint_mask) < min_hints) begin
                            min_hints <= count_ones(hint_mask);
                            best_mask <= hint_mask;
                        end
                    end
                    
                    // Increment hint_mask
                    if (hint_mask < 10'h3FF) begin
                        hint_mask <= hint_mask + 10'd1;
                        state <= INIT_LOOP;
                    end else begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result <= min_hints;
                    done <= 1'b1;
                    valid <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
    // Combinational logic for duplicate checking
    always @(*) begin
        found_duplicate = 1'b0;
        
        // Check all valid type pairs for duplicate signatures
        if (state == UPDATE_MIN) begin
            for (i = 0; i < 25; i = i + 1) begin
                if (valid_types[i]) begin
                    for (int j = i + 1; j < 25; j = j + 1) begin
                        if (valid_types[j]) begin
                            if (sig[i] == sig[j]) begin
                                found_duplicate = 1'b1;
                            end
                        end
                    end
                end
            end
        end
    end

endmodule