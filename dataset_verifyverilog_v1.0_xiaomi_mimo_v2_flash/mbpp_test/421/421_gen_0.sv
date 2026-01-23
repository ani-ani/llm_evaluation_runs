module tuple_concatenator (
    input wire clk,
    input wire rst_n,
    input wire start,
    
    // Input tuple elements (8-bit ASCII characters each)
    // Fixed 4-element tuple as specified in test cases
    input wire [7:0] elem0,
    input wire [7:0] elem1,
    input wire [7:0] elem2,
    input wire [7:0] elem3,
    
    // Output: concatenated string (max 32 characters, 256 bits)
    output reg [255:0] result,
    output reg [5:0] length,  // Actual length of result (0-32)
    output reg done
);

    // Constants
    localparam [7:0] DELIM = 8'h2D;  // ASCII '-' = 0x2D
    localparam [5:0] MAX_LEN = 6'd32;
    
    // State machine states
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] CONCAT0     = 3'd1;
    localparam [2:0] ADD_DELIM0  = 3'd2;
    localparam [2:0] CONCAT1     = 3'd3;
    localparam [2:0] ADD_DELIM1  = 3'd4;
    localparam [2:0] CONCAT2     = 3'd5;
    localparam [2:0] ADD_DELIM2  = 3'd6;
    localparam [2:0] CONCAT3     = 3'd7;
    localparam [2:0] COMPLETE    = 3'd8;
    
    reg [2:0] current_state;
    reg [2:0] next_state;
    
    // Internal registers for building result
    reg [255:0] result_reg;
    reg [5:0] pos_reg;  // Current position in result
    reg [5:0] cycle_count;
    localparam [5:0] MAX_CYCLES = 6'd50;
    
    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            result_reg <= 256'h0;
            pos_reg <= 6'd0;
            done <= 1'b0;
            length <= 6'd0;
            result <= 256'h0;
            cycle_count <= 6'd0;
        end else begin
            current_state <= next_state;
            
            case (current_state)
                IDLE: begin
                    result_reg <= 256'h0;
                    pos_reg <= 6'd0;
                    done <= 1'b0;
                    length <= 6'd0;
                    cycle_count <= 6'd0;
                end
                
                CONCAT0: begin
                    // Copy elem0 bytes to result (assuming 1 byte per char)
                    result_reg[7:0] <= elem0;
                    pos_reg <= 6'd1;
                    cycle_count <= cycle_count + 6'd1;
                end
                
                ADD_DELIM0: begin
                    result_reg[15:8] <= DELIM;
                    pos_reg <= 6'd2;
                    cycle_count <= cycle_count + 6'd1;
                end
                
                CONCAT1: begin
                    result_reg[23:16] <= elem1;
                    pos_reg <= 6'd3;
                    cycle_count <= cycle_count + 6'd1;
                end
                
                ADD_DELIM1: begin
                    result_reg[31:24] <= DELIM;
                    pos_reg <= 6'd4;
                    cycle_count <= cycle_count + 6'd1;
                end
                
                CONCAT2: begin
                    result_reg[39:32] <= elem2;
                    pos_reg <= 6'd5;
                    cycle_count <= cycle_count + 6'd1;
                end
                
                ADD_DELIM2: begin
                    result_reg[47:40] <= DELIM;
                    pos_reg <= 6'd6;
                    cycle_count <= cycle_count + 6'd1;
                end
                
                CONCAT3: begin
                    result_reg[55:48] <= elem3;
                    pos_reg <= 6'd7;
                    length <= 6'd7;  // 7 characters total
                    cycle_count <= cycle_count + 6'd1;
                end
                
                COMPLETE: begin
                    result <= result_reg;
                    done <= 1'b1;
                    cycle_count <= cycle_count + 6'd1;
                end
                
                default: begin
                    current_state <= IDLE;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = current_state;
        
        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = CONCAT0;
                end
            end
            
            CONCAT0: begin
                next_state = ADD_DELIM0;
            end
            
            ADD_DELIM0: begin
                next_state = CONCAT1;
            end
            
            CONCAT1: begin
                next_state = ADD_DELIM1;
            end
            
            ADD_DELIM1: begin
                next_state = CONCAT2;
            end
            
            CONCAT2: begin
                next_state = ADD_DELIM2;
            end
            
            ADD_DELIM2: begin
                next_state = CONCAT3;
            end
            
            CONCAT3: begin
                next_state = COMPLETE;
            end
            
            COMPLETE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule