module EvenNumberFilter(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:15],
    input [3:0] len,
    output reg [7:0] result [0:7],
    output reg [3:0] result_count,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] OUTPUT = 2'd2;
    
    reg [1:0] state;
    reg [3:0] index;
    reg [3:0] output_index;
    reg [7:0] current_value;
    reg is_even;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            output_index <= 4'd0;
            current_value <= 8'd0;
            is_even <= 1'b0;
            result_count <= 4'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            
            // Initialize result array
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                result[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= PROCESS;
                        index <= 4'd0;
                        output_index <= 4'd0;
                        result_count <= 4'd0;
                        
                        // Reset result array
                        integer i;
                        for (i = 0; i < 8; i = i + 1) begin
                            result[i] <= 8'd0;
                        end
                    end
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if we've processed all elements
                    if (index == len) begin
                        state <= OUTPUT;
                    end else begin
                        current_value <= arr[index];
                        is_even <= ~current_value[0];  // Check LSB for even
                        
                        if (is_even && output_index < 8) begin
                            result[output_index] <= current_value;
                            result_count <= result_count + 4'd1;
                            output_index <= output_index + 4'd1;
                        end
                        
                        index <= index + 4'd1;
                    end
                    
                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= OUTPUT;
                    end
                end
                
                OUTPUT: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule