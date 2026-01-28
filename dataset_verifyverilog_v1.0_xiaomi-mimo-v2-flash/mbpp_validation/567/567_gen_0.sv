module CheckSorted (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_0,
    input wire [7:0] arr_1,
    input wire [7:0] arr_2,
    input wire [7:0] arr_3,
    input wire [7:0] arr_4,
    input wire [7:0] arr_5,
    input wire [7:0] arr_6,
    input wire [7:0] arr_7,
    input wire [3:0] len,
    output reg result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] CHECK      = 3'd1;
    localparam [2:0] UNORDERED  = 3'd2;
    localparam [2:0] FINISHED   = 3'd3;
    
    // Internal registers
    reg [2:0] state;
    reg [3:0] index;
    reg [7:0] arr_reg [0:7];
    reg [3:0] len_reg;
    reg result_temp;
    
    // Cycle counter to prevent infinite loops
    reg [4:0] cycle_count;
    localparam [4:0] MAX_CYCLES = 5'd20;
    
    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            index <= 4'd0;
            len_reg <= 4'd0;
            result_temp <= 1'b0;
            cycle_count <= 5'd0;
            
            // Initialize array register
            for (i = 0; i < 8; i = i + 1) begin
                arr_reg[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 5'd0;
                    result_temp <= 1'b1;
                    
                    if (start) begin
                        // Capture inputs
                        arr_reg[0] <= arr_0;
                        arr_reg[1] <= arr_1;
                        arr_reg[2] <= arr_2;
                        arr_reg[3] <= arr_3;
                        arr_reg[4] <= arr_4;
                        arr_reg[5] <= arr_5;
                        arr_reg[6] <= arr_6;
                        arr_reg[7] <= arr_7;
                        len_reg <= len;
                        index <= 4'd0;
                        
                        // Special case: len < 2 means always sorted
                        if (len < 4'd2) begin
                            state <= FINISHED;
                        end else begin
                            state <= CHECK;
                        end
                    end
                end
                
                CHECK: begin
                    cycle_count <= cycle_count + 5'd1;
                    
                    // Compare arr[i] and arr[i+1]
                    if (arr_reg[index] > arr_reg[index + 4'd1]) begin
                        result_temp <= 1'b0;
                        state <= UNORDERED;
                    end else begin
                        // Move to next pair
                        index <= index + 4'd1;
                        
                        // Check if we've reached the last pair
                        if (index >= len_reg - 4'd2) begin
                            state <= FINISHED;
                        end else if (cycle_count >= MAX_CYCLES) begin
                            // Safety timeout (should not reach here with valid len)
                            state <= FINISHED;
                        end
                    end
                end
                
                UNORDERED: begin
                    // One more cycle to finish
                    cycle_count <= cycle_count + 5'd1;
                    state <= FINISHED;
                end
                
                FINISHED: begin
                    done <= 1'b1;
                    result <= result_temp;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    result <= 1'b0;
                end
            endcase
        end
    end

endmodule