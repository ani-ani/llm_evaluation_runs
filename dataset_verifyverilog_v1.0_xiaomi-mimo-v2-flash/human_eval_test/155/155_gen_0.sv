module digit_counter(
    input clk,
    input rst_n,
    input start,
    input signed [15:0] num,
    output reg [3:0] even_count,
    output reg [3:0] odd_count,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] ABS       = 3'd1;
    localparam [2:0] ZERO_CHECK = 3'd2;
    localparam [2:0] EXTRACT   = 3'd3;
    localparam [2:0] DONE      = 3'd4;

    reg [2:0] state, next_state;
    reg [15:0] temp_num;
    reg [3:0] digit;
    reg [2:0] digit_count;
    reg [3:0] even_reg;
    reg [3:0] odd_reg;
    reg start_delayed;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            temp_num <= 16'd0;
            digit <= 4'd0;
            digit_count <= 3'd0;
            even_reg <= 4'd0;
            odd_reg <= 4'd0;
            even_count <= 4'd0;
            odd_count <= 4'd0;
            done <= 1'b0;
            start_delayed <= 1'b0;
        end else begin
            start_delayed <= start;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        even_reg <= 4'd0;
                        odd_reg <= 4'd0;
                        digit_count <= 3'd0;
                    end
                end
                
                ABS: begin
                    if (num[15]) begin
                        temp_num <= ~num + 16'd1;
                    end else begin
                        temp_num <= num;
                    end
                end
                
                ZERO_CHECK: begin
                    // Check if temp_num is zero
                    if (temp_num == 16'd0) begin
                        even_reg <= 4'd1;
                        odd_reg <= 4'd0;
                    end
                end
                
                EXTRACT: begin
                    // Extract digit and increment counter
                    digit <= temp_num % 10;
                    digit_count <= digit_count + 3'd1;
                    
                    // Check if digit is even or odd
                    if ((temp_num % 10) % 2 == 0) begin
                        even_reg <= even_reg + 4'd1;
                    end else begin
                        odd_reg <= odd_reg + 4'd1;
                    end
                    
                    // Divide by 10 for next iteration
                    temp_num <= temp_num / 10;
                end
                
                DONE: begin
                    even_count <= even_reg;
                    odd_count <= odd_reg;
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start_delayed) begin
                    next_state = ABS;
                end else begin
                    next_state = IDLE;
                end
            end
            
            ABS: begin
                next_state = ZERO_CHECK;
            end
            
            ZERO_CHECK: begin
                if (temp_num == 16'd0) begin
                    next_state = DONE;
                end else begin
                    next_state = EXTRACT;
                end
            end
            
            EXTRACT: begin
                if (temp_num == 16'd0 || digit_count >= 3'd5) begin
                    next_state = DONE;
                end else begin
                    next_state = EXTRACT;
                end
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule