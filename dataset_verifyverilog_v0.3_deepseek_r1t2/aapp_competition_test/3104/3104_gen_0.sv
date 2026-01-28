module equation_solver(\n    input clk,\n    input rst_n,\n    input start,\n    input [3:0] digits[0:7],\n    input [3:0] length,\n    input [7:0] target,\n    output reg done,\n    output reg [7:0] split,\n    output reg valid\n);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] PROCESS = 3'd1;
    localparam [2:0] FOUND   = 3'd2;
    
    reg [2:0] state;
    reg [7:0] pattern_counter;
    wire [7:0] current_pattern = pattern_counter;
    
    // Sum computation variables
    reg [31:0] total_sum;
    reg [31:0] current_num;
    integer i;
    
    // Combinational sum calculation block
    always @(*) begin
        total_sum = 32'd0;
        current_num = 32'd0;
        for (i = 0; i < length; i = i + 1) begin
            current_num = (current_num * 32'd10) + {28'd0, digits[i]};
            if ((i < (length - 1)) && current_pattern[i]) begin
                total_sum = total_sum + current_num;
                current_num = 32'd0;
            end
        end
        total_sum = total_sum + current_num;
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            valid <= 1'b0;
            split <= 8'd0;
            pattern_counter <= 8'd0;
        end else begin
            done <= 1'b0;
            valid <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        pattern_counter <= 8'd0;
                        state <= PROCESS;
                    end
                end
                
                PROCESS: begin
                    if (total_sum == {24'd0, target}) begin
                        split <= current_pattern & ((8'd1 << (length - 4'd1)) - 8'd1);
                        state <= FOUND;
                    end else begin
                        pattern_counter <= pattern_counter + 8'd1;
                    end
                end
                
                FOUND: begin
                    done <= 1'b1;
                    valid <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
endmodule