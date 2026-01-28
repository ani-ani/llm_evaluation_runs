module remove_uppercase (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] input_string,
    input wire [3:0] input_length,
    output reg [127:0] output_string,
    output reg [3:0] output_length,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PROCESS = 3'd1;
    localparam [2:0] FINISH = 3'd2;
    
    reg [2:0] state, next_state;
    reg [3:0] input_index;
    reg [3:0] output_index;
    reg [7:0] current_char;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd16;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            input_index <= 4'd0;
            output_index <= 4'd0;
            current_char <= 8'd0;
            output_string <= 128'd0;
            output_length <= 4'd0;
            done <= 1'b0;
            cycle_count <= 4'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        next_state = PROCESS;
                        input_index <= 4'd0;
                        output_index <= 4'd0;
                    end else begin
                        next_state = IDLE;
                    end
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 4'd1;
                    
                    // Read current character
                    current_char = input_string[(input_index * 8'b111) +: 8];
                    
                    // Check if not uppercase (A-Z: 65-90)
                    if (current_char < 8'd65 || current_char > 8'd90) begin
                        // Copy to output buffer
                        output_string[(output_index * 8'b111) +: 8] = current_char;
                        output_index = output_index + 4'd1;
                    end
                    
                    // Move to next input character
                    input_index = input_index + 4'd1;
                    
                    // Check if done processing
                    if (input_index == input_length || cycle_count >= MAX_CYCLES) begin
                        next_state = FINISH;
                    end else begin
                        next_state = PROCESS;
                    end
                end
                
                FINISH: begin
                    output_length = output_index;
                    done <= 1'b1;
                    next_state = IDLE;
                end
                
                default: next_state = IDLE;
            endcase
        end
    end

endmodule