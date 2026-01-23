module EvenNumberFilter(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    input [2:0] len,
    output reg [7:0] result [0:7],
    output reg [2:0] output_len,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] PROCESS = 3'd1;
    localparam [2:0] FINISH  = 3'd2;
    
    reg [2:0] state;
    reg [2:0] index;
    reg [2:0] output_index;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd16;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 3'd0;
            output_index <= 3'd0;
            output_len <= 3'd0;
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
                        index <= 3'd0;
                        output_index <= 3'd0;
                        output_len <= 3'd0;
                    end
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if current element is even
                    if (arr[index][0] == 1'b0) begin
                        result[output_index] <= arr[index];
                        output_index <= output_index + 3'd1;
                    end
                    
                    // Move to next index
                    index <= index + 3'd1;
                    
                    // Check if processing is complete
                    if (index == len || cycle_count >= MAX_CYCLES) begin
                        output_len <= output_index;
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule