module bill_finder (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] P,
    output reg [15:0] b_out,
    output reg [15:0] m_out,
    output reg valid,
    output reg done,
    output reg [13:0] count
);
    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] CALC_M     = 3'd1;
    localparam [2:0] CHECK_DIGITS = 3'd2;
    localparam [2:0] OUTPUT     = 3'd3;
    localparam [2:0] INCREMENT  = 3'd4;
    localparam [2:0] FINISHED   = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [15:0] current_b;
    reg [15:0] current_m;
    reg [15:0] p_reg;
    reg [13:0] total_count;
    
    // Digit mask registers (10 bits for digits 0-9)
    reg [9:0] mask_p;
    reg [9:0] mask_b;
    reg [9:0] mask_m;
    
    // Temporary registers for digit extraction
    reg [15:0] temp_num;
    reg [3:0] digit;
    reg [9:0] new_mask;
    
    // Control flags
    reg extracting_p;
    reg extracting_b;
    reg extracting_m;
    reg extraction_done;
    reg [3:0] digit_index;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_b <= 16'd0;
            current_m <= 16'd0;
            p_reg <= 16'd0;
            total_count <= 14'd0;
            b_out <= 16'd0;
            m_out <= 16'd0;
            valid <= 1'b0;
            done <= 1'b0;
            count <= 14'd0;
            mask_p <= 10'd0;
            mask_b <= 10'd0;
            mask_m <= 10'd0;
            temp_num <= 16'd0;
            digit <= 4'd0;
            new_mask <= 10'd0;
            extracting_p <= 1'b0;
            extracting_b <= 1'b0;
            extracting_m <= 1'b0;
            extraction_done <= 1'b0;
            digit_index <= 4'd0;
        end else begin
            state <= next_state;
            
            // Default outputs
            valid <= 1'b0;
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        current_b <= 16'd1;
                        total_count <= 14'd0;
                        p_reg <= P;
                        extracting_p <= 1'b1;
                        extracting_b <= 1'b0;
                        extracting_m <= 1'b0;
                        temp_num <= P;
                        mask_p <= 10'd0;
                        digit_index <= 4'd0;
                    end
                end
                
                CALC_M: begin
                    current_m <= p_reg - current_b;
                    mask_m <= 10'd0;
                    mask_b <= 10'd0;
                    extracting_b <= 1'b1;
                    extracting_m <= 1'b0;
                    temp_num <= current_b;
                    digit_index <= 4'd0;
                end
                
                CHECK_DIGITS: begin
                    // Digit extraction logic
                    if (!extraction_done) begin
                        digit <= temp_num % 10;
                        temp_num <= temp_num / 10;
                        
                        case (digit)
                            4'd0: new_mask <= 10'b0000000001;
                            4'd1: new_mask <= 10'b0000000010;
                            4'd2: new_mask <= 10'b0000000100;
                            4'd3: new_mask <= 10'b0000001000;
                            4'd4: new_mask <= 10'b0000010000;
                            4'd5: new_mask <= 10'b0000100000;
                            4'd6: new_mask <= 10'b0001000000;
                            4'd7: new_mask <= 10'b0010000000;
                            4'd8: new_mask <= 10'b0100000000;
                            4'd9: new_mask <= 10'b1000000000;
                            default: new_mask <= 10'd0;
                        endcase
                        
                        digit_index <= digit_index + 4'd1;
                    end else begin
                        extraction_done <= 1'b0;
                        digit_index <= 4'd0;
                    end
                end
                
                OUTPUT: begin
                    b_out <= current_b;
                    m_out <= current_m;
                    valid <= 1'b1;
                    total_count <= total_count + 14'd1;
                    count <= total_count + 14'd1;
                end
                
                INCREMENT: begin
                    current_b <= current_b + 16'd1;
                end
                
                FINISHED: begin
                    done <= 1'b1;
                    count <= total_count;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
            
            // Handle digit extraction updates
            if (state == CHECK_DIGITS && !extraction_done && digit_index > 4'd0) begin
                if (extracting_p) begin
                    mask_p <= mask_p | new_mask;
                end else if (extracting_b) begin
                    mask_b <= mask_b | new_mask;
                end else if (extracting_m) begin
                    mask_m <= mask_m | new_mask;
                end
            end
            
            // Check if extraction is done (temp_num == 0)
            if (state == CHECK_DIGITS && temp_num == 16'd0) begin
                extraction_done <= 1'b1;
            end
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = CHECK_DIGITS; // Extract P digits
                else next_state = IDLE;
            end
            
            CALC_M: begin
                next_state = CHECK_DIGITS; // Extract B digits
            end
            
            CHECK_DIGITS: begin
                if (extraction_done) begin
                    if (extracting_p) begin
                        next_state = CALC_M; // Start checking B
                    end else if (extracting_b) begin
                        extracting_b = 1'b0;
                        extracting_m = 1'b1;
                        temp_num = current_m;
                        extraction_done = 1'b0;
                        digit_index = 4'd0;
                        next_state = CHECK_DIGITS; // Continue with M
                    end else if (extracting_m) begin
                        extracting_m = 1'b0;
                        next_state = OUTPUT; // Check validity
                    end else begin
                        next_state = OUTPUT;
                    end
                end else begin
                    next_state = CHECK_DIGITS;
                end
            end
            
            OUTPUT: begin
                if ((mask_b & mask_m) == 10'd0 && 
                    (mask_b & mask_p) == 10'd0 && 
                    (mask_m & mask_p) == 10'd0) begin
                    // Valid bill found
                    next_state = INCREMENT;
                end else begin
                    // Not valid, skip
                    next_state = INCREMENT;
                end
            end
            
            INCREMENT: begin
                if (current_b >= (p_reg >> 1)) begin
                    next_state = FINISHED;
                end else begin
                    next_state = CALC_M;
                end
            end
            
            FINISHED: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule