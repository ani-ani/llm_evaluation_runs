module CountOccurrences (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:7],
    input wire [7:0] target,
    input wire [3:0] len,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] CHECK   = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    reg [1:0] state;
    reg [3:0] index;          // Current array index (0-7)
    reg [3:0] count_internal; // Internal count register
    reg [4:0] cycle_count;    // Cycle counter (max 20)
    localparam [4:0] MAX_CYCLES = 5'd20;

    // Synchronous logic with active-low reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            index <= 4'd0;
            count_internal <= 4'd0;
            cycle_count <= 5'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    index <= 4'd0;
                    count_internal <= 4'd0;
                    cycle_count <= 5'd0;
                    
                    if (start) begin
                        state <= CHECK;
                    end
                end
                
                CHECK: begin
                    cycle_count <= cycle_count + 5'd1;
                    
                    // Compare current element with target
                    if (arr[index] == target) begin
                        count_internal <= count_internal + 4'd1;
                    end
                    
                    // Increment index
                    index <= index + 4'd1;
                    
                    // Check if we've processed all elements OR exceeded max cycles
                    if ((index + 4'd1 >= len) || (cycle_count >= MAX_CYCLES)) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result <= {4'd0, count_internal}; // Convert 4-bit to 8-bit
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule