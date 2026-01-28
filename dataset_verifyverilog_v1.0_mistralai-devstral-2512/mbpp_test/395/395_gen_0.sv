module first_non_repeated_char(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] str [0:15],
    output reg [7:0] result,
    output reg done
);
    
    // State declarations
    localparam [1:0] IDLE       = 2'd0;
    localparam [1:0] COUNT_PASS = 2'd1;
    localparam [1:0] SEARCH_PASS = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;
    
    // Internal registers
    reg [1:0] state, next_state;
    reg [7:0] result_reg;
    reg [3:0] index;
    reg [15:0] count_array [0:15]; // 2 bits per character (0-3 counts)
    reg [7:0] current_char;
    reg found;
    
    // Initialize count array
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            index <= 4'd0;
            result_reg <= 8'd0;
            found <= 1'b0;
            
            // Initialize count array
            for (i = 0; i < 16; i = i + 1) begin
                count_array[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    index <= 4'd0;
                    result_reg <= 8'd0;
                    found <= 1'b0;
                    
                    // Initialize count array
                    for (i = 0; i < 16; i = i + 1) begin
                        count_array[i] <= 16'd0;
                    end
                end
                
                COUNT_PASS: begin
                    // Update count for current character
                    current_char = str[index];
                    
                    // Increment count (saturate at 3)
                    if (count_array[index] < 16'd3) begin
                        count_array[index] <= count_array[index] + 16'd1;
                    end
                    
                    // Move to next index
                    if (index == 4'd15) begin
                        index <= 4'd0;
                    end else begin
                        index <= index + 4'd1;
                    end
                end
                
                SEARCH_PASS: begin
                    current_char = str[index];
                    
                    // Check if count is 1
                    if (count_array[index] == 16'd1 && !found) begin
                        result_reg <= current_char;
                        found <= 1'b1;
                    end
                    
                    // Move to next index
                    if (index == 4'd15) begin
                        index <= 4'd0;
                    end else begin
                        index <= index + 4'd1;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = COUNT_PASS;
                end else begin
                    next_state = IDLE;
                end
            end
            
            COUNT_PASS: begin
                if (index == 4'd15) begin
                    next_state = SEARCH_PASS;
                end else begin
                    next_state = COUNT_PASS;
                end
            end
            
            SEARCH_PASS: begin
                if (index == 4'd15 || found) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = SEARCH_PASS;
                end
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Output result
    always @(*) begin
        if (state == DONE_STATE) begin
            result = result_reg;
        end else begin
            result = 8'd0;
        end
    end
    
endmodule