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
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] SEARCH  = 2'd1;
    localparam [1:0] OUTPUT  = 2'd2;
    localparam [1:0] DONE    = 2'd3;
    
    // Internal registers
    reg [1:0] state, next_state;
    reg [15:0] current_B;
    reg [15:0] current_M;
    reg [9:0] mask_P, mask_B, mask_M;
    reg [13:0] valid_count;
    reg [15:0] b_reg, m_reg;
    reg valid_reg, done_reg;
    
    // Digit extraction function
    function [9:0] extract_digits;
        input [15:0] num;
        reg [9:0] mask;
        integer i;
        begin
            mask = 10'd0;
            for (i = 0; i < 5; i = i + 1) begin
                if (num > 0) begin
                    mask[num % 10] = 1'b1;
                    num = num / 10;
                end
            end
            extract_digits = mask;
        end
    endfunction
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_B <= 16'd1;
            current_M <= 16'd0;
            mask_P <= 10'd0;
            mask_B <= 10'd0;
            mask_M <= 10'd0;
            valid_count <= 14'd0;
            b_out <= 16'd0;
            m_out <= 16'd0;
            valid <= 1'b0;
            done <= 1'b0;
            count <= 14'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        mask_P = extract_digits(P);
                        current_B = 16'd1;
                        next_state = SEARCH;
                    end
                end
                
                SEARCH: begin
                    current_M = P - current_B;
                    
                    // Check B < M
                    if (current_B < current_M) begin
                        mask_B = extract_digits(current_B);
                        mask_M = extract_digits(current_M);
                        
                        // Check digit exclusivity
                        if ((mask_B & mask_M) == 0 && 
                            (mask_B & mask_P) == 0 && 
                            (mask_M & mask_P) == 0) begin
                            b_reg = current_B;
                            m_reg = current_M;
                            valid_reg = 1'b1;
                            next_state = OUTPUT;
                        end else begin
                            current_B = current_B + 16'd1;
                        end
                    end else begin
                        next_state = DONE;
                    end
                end
                
                OUTPUT: begin
                    b_out = b_reg;
                    m_out = m_reg;
                    valid = valid_reg;
                    valid_reg = 1'b0;
                    valid_count = valid_count + 14'd1;
                    current_B = current_B + 16'd1;
                    next_state = SEARCH;
                end
                
                DONE: begin
                    done = 1'b1;
                    count = valid_count;
                    next_state = IDLE;
                end
                
                default: next_state = IDLE;
            endcase
        end
    end
    
    // Default assignments
    assign b_out = (state == OUTPUT) ? b_reg : 16'd0;
    assign m_out = (state == OUTPUT) ? m_reg : 16'd0;
    assign valid = (state == OUTPUT) ? 1'b1 : 1'b0;
    assign done = (state == DONE) ? 1'b1 : 1'b0;
    assign count = valid_count;
    
endmodule