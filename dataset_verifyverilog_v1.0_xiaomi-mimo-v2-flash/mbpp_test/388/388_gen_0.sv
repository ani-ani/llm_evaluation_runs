module highest_power_of_2 (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] n,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] CHECK    = 3'd1;
    localparam [2:0] UPDATE   = 3'd2;
    localparam [3:0] NEXT_BIT = 3'd3;
    localparam [2:0] FINISH   = 3'd4;
    
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Computation registers
    reg [15:0] result_reg;
    reg [15:0] temp_reg;
    reg [15:0] bit_mask;
    reg [3:0] bit_counter; // 0 to 15
    
    // Control signals
    reg computing;
    
    // FSM next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CHECK;
                end else begin
                    next_state = IDLE;
                end
            end
            
            CHECK: begin
                next_state = UPDATE;
            end
            
            UPDATE: begin
                next_state = NEXT_BIT;
            end
            
            NEXT_BIT: begin
                if (bit_counter == 4'd15) begin
                    next_state = FINISH;
                end else begin
                    next_state = CHECK;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            result <= 16'd0;
            result_reg <= 16'd0;
            temp_reg <= 16'd0;
            bit_mask <= 16'd0;
            bit_counter <= 4'd0;
            done <= 1'b0;
            computing <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Initialize computation
                        result_reg <= 16'd0;
                        bit_counter <= 4'd0;
                        bit_mask <= 16'h8000; // Start with MSB (bit 15)
                        computing <= 1'b1;
                    end
                end
                
                CHECK: begin
                    // Compute temp = result | (1 << i)
                    temp_reg <= result_reg | bit_mask;
                end
                
                UPDATE: begin
                    // If temp <= n, update result
                    if (temp_reg <= n) begin
                        result_reg <= temp_reg;
                    end
                end
                
                NEXT_BIT: begin
                    // Move to next bit position
                    bit_counter <= bit_counter + 4'd1;
                    bit_mask <= bit_mask >> 1; // Shift right for next bit
                end
                
                FINISH: begin
                    // Complete computation
                    result <= result_reg;
                    done <= 1'b1;
                    computing <= 1'b0;
                end
                
                default: begin
                    // State recovery
                    result_reg <= 16'd0;
                    bit_counter <= 4'd0;
                    bit_mask <= 16'd0;
                    computing <= 1'b0;
                end
            endcase
        end
    end

endmodule