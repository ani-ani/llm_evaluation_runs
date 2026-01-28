module sum_squares(
    input clk,
    input rst_n,
    input start,
    input signed [15:0] arr[0:15],
    input [3:0] len,
    output reg signed [15:0] result,
    output reg done
);

    // FSM State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    // Registers and wires
    reg [1:0] state, next_state;
    reg [3:0] index;
    reg signed [31:0] temp_sum;
    reg signed [31:0] processed_val;
    reg signed [31:0] temp_reg;
    reg signed [31:0] square_result;
    reg signed [47:0] cube_result;
    
    // Processing flags
    wire is_mod3;
    wire is_mod4;
    wire is_done;
    
    // Index modulo calculations (combinational)
    assign is_mod3 = (index % 3) == 0;
    assign is_mod4 = (index % 4) == 0;
    assign is_done = (index >= len) && (len != 0);
    
    // FSM Next State Logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESS;
                end else begin
                    next_state = IDLE;
                end
            end
            
            PROCESS: begin
                if (is_done) begin
                    next_state = FINISH;
                end else begin
                    next_state = PROCESS;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // FSM Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            index <= 4'd0;
            temp_sum <= 32'sd0;
            processed_val <= 32'sd0;
            temp_reg <= 32'sd0;
            square_result <= 32'sd0;
            cube_result <= 48'sd0;
            result <= 16'sd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        index <= 4'd0;
                        temp_sum <= 32'sd0;
                        // Handle len=0 case immediately
                        if (len == 4'd0) begin
                            result <= 16'sd0;
                            done <= 1'b1;
                            next_state <= IDLE;
                        end
                    end
                end
                
                PROCESS: begin
                    // Calculate transformation based on index
                    if (is_mod3) begin
                        // Square: need 32-bit intermediate
                        // 16-bit signed squared = 32-bit signed
                        temp_reg <= arr[index];
                        square_result <= arr[index] * arr[index];
                        // Take top 16 bits for final result (with saturation/clamping)
                        processed_val <= {16{square_result[31]}}; // Sign extend top bit
                        processed_val[15:0] <= square_result[31:16];
                    end else if (is_mod4) begin
                        // Cube: need 48-bit intermediate for 16-bit signed
                        // Use temp_reg as intermediate
                        temp_reg <= arr[index];
                        // First calculate square (16x16 -> 32)
                        square_result <= arr[index] * arr[index];
                        // Then multiply by original (32x16 -> 48)
                        cube_result <= (arr[index] * arr[index]) * arr[index];
                        // Take top 16 bits
                        processed_val <= {16{cube_result[47]}}; // Sign extend
                        processed_val[15:0] <= cube_result[47:32];
                    end else begin
                        // Keep unchanged (sign extend to 32-bit)
                        processed_val <= {{16{arr[index][15]}}, arr[index]};
                    end
                    
                    // Add to accumulator (32-bit sum)
                    if (index < len) begin
                        temp_sum <= temp_sum + processed_val;
                    end
                    
                    // Increment index
                    index <= index + 4'd1;
                    
                    // Check for completion
                    if (is_done) begin
                        // Clamp final result to 16-bit signed
                        if (temp_sum > 32'sd32767) begin
                            result <= 16'sd32767;
                        end else if (temp_sum < -32'sd32768) begin
                            result <= -16'sd32768;
                        end else begin
                            result <= temp_sum[15:0];
                        end
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    // state returns to IDLE next cycle
                end
                
                default: begin
                    state <= IDLE;
                    index <= 4'd0;
                    temp_sum <= 32'sd0;
                    done <= 1'b0;
                end
            endcase
            
            state <= next_state;
        end
    end

endmodule